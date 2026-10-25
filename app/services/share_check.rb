class ShareCheck
  URL = %r{https?://[^\s<>"']+}i
  SEPARATORS = /\s+[-|\u2013\u2014]\s+|\s*:\s+|\s+by\s+|,\s+|\n/
  NOISE = /amazon|litres|литрес|audible|kindle store|\Abooks\z|аудиокниг|слушать|читать|скачать|онлайн/i
  FORMAT_WORDS = /\b(?:kindle edition|audible audiobook|audiobook|ebook|paperback|hardcover)\b/i
  ISBN = /\A(?:97[89])?\d{9}[\dX]\z/
  MAX_TEXT = 2000

  def self.status_label(status, format)
    audio = format == "audio"
    key = { "in_progress" => audio ? :listening : :reading, "done" => audio ? :listened : :read }
      .fetch(status, status.to_sym)
    I18n.t("share.#{key}")
  end

  attr_reader :user, :url, :text

  def initialize(user, url: nil, text: nil)
    @user = user
    @text = text.to_s.first(MAX_TEXT)
    @url = url.presence || @text[URL]
  end

  def call
    link = resolve
    query, books = (link && by_link(link)) || by_text || [ segments.first || link&.external_id.to_s, [] ]
    result = ShelfSearch.new(user, query).result(books)
    result[:answer] = { kind: "unrecognized" } if link.nil? && segments.empty?
    result.merge(message: message(result), link: link&.to_h, suggestion: suggestion(result, link))
  end

  private

  def resolve
    LinkResolver.new.call(url) if url
  rescue LinkResolver::Failed => e
    Rails.logger.info({ event: "share.link_failed", user_id: user.id, reason: e.message }.to_json)
    nil
  end

  def by_link(link)
    books = with_editions(user.books.where(id: user.editions.where(link.to_h).select(:book_id)))
    [ link.external_id, books ] if books.any?
  end

  # Matches titles only: an author segment matching one other book of the author would
  # answer "read" for the wrong book.
  def by_text
    return if segments.empty?

    keys = segments.map { TextKey.title(it) }.compact_blank
    exact = user.books.where(title_key: keys).or(user.books.where(original_title_key: keys)).or(user.books.where(isbn: isbns))
    books = with_editions(exact)
    return [ segments.first, books ] if books.any?

    segments.each do |segment|
      next if segment.length < 4

      like = "%#{Book.sanitize_sql_like(segment)}%"
      books = with_editions(user.books.where("title ILIKE :like OR original_title ILIKE :like", like:))
      return [ segment, books ] if books.any?
    end
    nil
  end

  def with_editions(scope) = scope.includes(editions: :reading).order(:title).limit(ShelfSearch::LIMIT).to_a

  def segments
    @segments ||= text.gsub(URL, " ").split(SEPARATORS)
      .map { it.gsub(FORMAT_WORDS, " ").squish }
      .reject { it.length < 2 || it.match?(NOISE) }
      .uniq.first(8)
  end

  def isbns = segments.map { it.delete("-") }.grep(ISBN)

  def suggestion(result, link)
    return unless result[:answer][:kind].in?(%w[not_found unrecognized])

    title, author = segments.reject { it.delete("-").match?(ISBN) }
    { title:, author:, store: link&.store, external_id: link&.external_id }
  end

  def message(result)
    kind = result[:answer][:kind]
    editions = result[:books].first&.dig(:editions) || []
    case kind
    when "listened" then line(:listened, month_year(finished(editions, audio: true)))
    when "read" then line(:read, finished(editions, audio: false)&.year)
    when "read_and_listened"
      years = [ finished(editions, audio: false), finished(editions, audio: true) ].compact.map(&:year).uniq.sort
      line(:read_and_listened, years.join(", ").presence)
    when "in_progress"
      self.class.status_label("in_progress", editions.find { it[:status] == "in_progress" }&.dig(:format))
    when "want"
      since = editions.select { it[:status] == "want" }.filter_map { it[:status_updated_at] }.min
      since ? I18n.t("share.want_since", date: month_year(since, :months_since)) : I18n.t("share.want")
    when "similar" then I18n.t("share.similar", count: result[:answer][:count])
    else I18n.t("share.#{kind}")
    end
  end

  def finished(editions, audio:)
    editions.select { it[:status] == "done" && (it[:format] == "audio") == audio }.filter_map { it[:finished_at] }.max
  end

  def line(key, detail) = [ I18n.t("share.#{key}"), detail ].compact.join(" · ")

  def month_year(time, months = :months)
    time && "#{I18n.t("share.#{months}")[time.month]} #{time.year}"
  end
end
