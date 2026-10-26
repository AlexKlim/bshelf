class LitresImport
  SOURCE = "litres".freeze
  FORMATS = { 0 => "ebook", 1 => "audio", 4 => "ebook" }.freeze

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
      return false
    end

    attrs = { format: FORMATS.fetch(art["art_type"], "unknown"), status:, source: SOURCE,
      store: "litres", external_id: id.to_s, status_source: SOURCE }
    AddBook.call(user: @user, title:, author: author(art), **attrs)
    true
  rescue AddBook::Duplicate => e
    AddBook.add_edition(e.book, **attrs)
    true
  end

  def author(art)
    people = Array(art["persons"]).select { it["role"] == "author" }.pluck("full_name")
    people = Array(art["authors"]).map { it.is_a?(Hash) ? it["full_name"] : it } if people.empty?
    people.compact_blank.join(", ").presence
  end
end
