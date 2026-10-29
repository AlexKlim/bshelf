class StorytelImport
  SOURCE = "storytel".freeze
  STATUSES = { "CONSUMING" => "in_progress", "CONSUMED" => "done" }.freeze

  def self.call(user, items) = new(user).call(items)

  def initialize(user)
    @user = user
  end

  def call(items)
    { books: items.count { |item| upsert(item["model"] || {}) unless item["action"].to_s.match?(/remove|delete/i) }, highlights: 0 }
  end

  private

  def upsert(model)
    id, title = model.values_at("id", "title")
    return false if id.blank? || title.blank?

    status = STATUSES.fetch(model["state"], "want")
    if (edition = @user.editions.find_by(store: "storytel", external_id: id.to_s))
      StatusResolver.automatic!(edition.reading, status:, source: SOURCE)
      cover(edition.book, model)
      return false
    end

    return false if @user.discarded_editions.exists?(store: "storytel", external_id: id.to_s)

    attrs = { format: format(model), status:, source: SOURCE, store: "storytel", external_id: id.to_s, status_source: SOURCE }
    cover(AddBook.call(user: @user, title:, author: names(model["authors"]), **attrs), model)
    true
  rescue AddBook::Duplicate => e
    AddBook.add_edition(e.book, **attrs)
    cover(e.book, model)
    true
  end

  def formats(model) = Array(model["formats"]).select { it.is_a?(Hash) }

  def format(model) = formats(model).any? { it["type"] == "abook" } ? "audio" : "ebook"

  def cover(book, model)
    url = formats(model).filter_map { it.dig("cover", "url") }.first
    book.update!(cover_url: url) if url.is_a?(String) && url.start_with?("https://") && book.cover_url.nil?
  end

  def names(people) = Array(people).filter_map { it["name"] if it.is_a?(Hash) }.compact_blank.join(", ").presence
end
