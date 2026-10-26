class LitresImport
  SOURCE = "litres".freeze
  FORMATS = { 0 => "ebook", 1 => "audio", 4 => "ebook" }.freeze
  SITE = "https://www.litres.ru".freeze

  def self.call(user, arts) = new(user).call(arts)

  def initialize(user)
    @user = user
  end

  def call(arts)
    { books: arts.count { |art| upsert(art) }, highlights: 0 }
  end

  private

  def upsert(art)
    id, title = art.values_at("id", "title")
    return false if id.blank? || title.blank?

    status = art["status"] || "owned"
    if (edition = @user.editions.find_by(store: "litres", external_id: id.to_s))
      StatusResolver.automatic!(edition.reading, status:, source: SOURCE)
      cover(edition.book, art)
      return false
    end

    attrs = { format: FORMATS.fetch(art["art_type"], "unknown"), status:, source: SOURCE,
      store: "litres", external_id: id.to_s, status_source: SOURCE }
    cover(AddBook.call(user: @user, title:, author: author(art), **attrs), art)
    true
  rescue AddBook::Duplicate => e
    AddBook.add_edition(e.book, **attrs)
    cover(e.book, art)
    true
  end

  def cover(book, art)
    url = art["cover_url"]
    book.update!(cover_url: URI.join(SITE, url).to_s) if url.is_a?(String) && url.present? && book.cover_url.nil?
  rescue URI::Error
    nil
  end

  def author(art)
    people = Array(art["persons"]).select { it["role"] == "author" }.pluck("full_name")
    people = Array(art["authors"]).map { it.is_a?(Hash) ? it["full_name"] : it } if people.empty?
    people.compact_blank.join(", ").presence
  end
end
