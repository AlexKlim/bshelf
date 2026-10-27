class KindleImport
  SOURCE = "kindle_browser".freeze
  FORMATS = { "Ebook" => "ebook", "KindlePDoc" => "ebook", "Audible" => "audio" }.freeze

  def self.call(user, items, highlights, owned = {}) = new(user).call(items, highlights, owned)

  def self.decode(text) = text.to_s.gsub(/&#?[[:alnum:]]+;/) { Nokogiri::HTML5.fragment(it).text }

  def initialize(user)
    @user = user
  end

  def call(items, highlights, owned = {})
    added = with_owned(items, owned).count { |item| upsert(item) }
    books = @user.editions.where(store: "amazon", external_id: highlights.keys).pluck(:external_id, :book_id).to_h
    saved = highlights.sum { |asin, notes| books[asin] ? replace_highlights(books[asin], notes) : 0 }
    { books: added, highlights: saved }
  end

  private

  # "Manage your content" adds Kindle's own READ mark, documents and audiobooks the reader library does not list.
  def with_owned(items, owned)
    read = owned.fetch("Ebook", []).select { it["readStatus"] == "READ" }.pluck("asin").to_set
    known = items.pluck("asin").to_set
    extra = owned.flat_map do |kind, list|
      list.reject { known.include?(it["asin"]) || it["originType"] == "KindleDictionary" }.map { owned_item(it, kind) }
    end
    items.map { read.include?(it["asin"]) ? it.merge("percentageRead" => 100) : it } + extra
  end

  def owned_item(item, kind)
    authors = Array(item["bookProducerDetails"]).select { it["role"] == "author" }.pluck("name")
    authors = item["authors"].to_s.split(",") if authors.empty?
    { "asin" => item["asin"], "title" => item["title"].to_s.strip, "authors" => authors.map(&:strip),
      "originType" => item["originType"].to_s.casecmp?("sample") ? "SAMPLE" : item["originType"],
      "percentageRead" => item["readStatus"] == "READ" ? 100 : 0, "format" => FORMATS.fetch(kind, "ebook"),
      "productUrl" => item["productImage"] }
  end

  def upsert(item)
    asin = item["asin"]
    title = FileTitle.clean(self.class.decode(item["title"]).strip)
    return false if asin.blank? || title.blank?

    status = status_for(item)
    if (edition = @user.editions.find_by(store: "amazon", external_id: asin))
      StatusResolver.automatic!(edition.reading, status:, source: SOURCE)
      cover(edition.book, item)
      return false
    end

    attrs = { format: item["format"] || "ebook", status:, source: SOURCE, store: "amazon", external_id: asin, status_source: SOURCE }
    cover(AddBook.call(user: @user, title:, author: author(item["authors"]), **attrs), item)
    true
  rescue AddBook::Duplicate => e
    AddBook.add_edition(e.book, **attrs)
    cover(e.book, item)
    true
  end

  def cover(book, item)
    url = item["productUrl"]
    return unless url.is_a?(String) && url.include?("/images/I/") && book.cover_url.nil?

    book.update!(cover_url: url.sub(/\Ahttp:/, "https:"))
  end

  def status_for(item)
    return "want" if item["originType"] == "SAMPLE"

    percent = item["percentageRead"].to_i
    if percent >= 100 then "done"
    elsif percent.positive? then "in_progress"
    else "owned"
    end
  end

  def author(names)
    Array(names).map { self.class.decode(it).delete_suffix(":").split(", ", 2).reverse.join(" ").squish }.compact_blank.join(", ").presence
  end

  def replace_highlights(book_id, notes)
    Highlight.transaction do
      @user.highlights.where(book_id:, source: SOURCE).delete_all
      notes.each { @user.highlights.create!(book_id:, source: SOURCE, **it.symbolize_keys.slice(:text, :note, :location)) }
    end
    notes.size
  end
end
