class KindleImport
  SOURCE = "kindle_browser".freeze

  def self.call(user, items, highlights) = new(user).call(items, highlights)

  def initialize(user)
    @user = user
  end

  def call(items, highlights)
    added = items.count { |item| upsert(item) }
    books = @user.editions.where(store: "amazon", external_id: highlights.keys).pluck(:external_id, :book_id).to_h
    saved = highlights.sum { |asin, notes| books[asin] ? replace_highlights(books[asin], notes) : 0 }
    { books: added, highlights: saved }
  end

  private

  def upsert(item)
    asin, title = item.values_at("asin", "title")
    return false if asin.blank? || title.blank?

    status = status_for(item)
    if (edition = @user.editions.find_by(store: "amazon", external_id: asin))
      StatusResolver.automatic!(edition.reading, status:, source: SOURCE)
      return false
    end

    attrs = { format: "ebook", status:, source: SOURCE, store: "amazon", external_id: asin, status_source: SOURCE }
    AddBook.call(user: @user, title:, author: author(item["authors"]), **attrs)
    true
  rescue AddBook::Duplicate => e
    AddBook.add_edition(e.book, **attrs)
    true
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
    Array(names).map { it.delete_suffix(":").split(", ", 2).reverse.join(" ").squish }.compact_blank.join(", ").presence
  end

  def replace_highlights(book_id, notes)
    Highlight.transaction do
      @user.highlights.where(book_id:, source: SOURCE).delete_all
      notes.each { @user.highlights.create!(book_id:, source: SOURCE, **it.symbolize_keys.slice(:text, :note, :location)) }
    end
    notes.size
  end
end
