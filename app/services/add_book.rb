class AddBook
  class Duplicate < StandardError
    attr_reader :book

    def initialize(book)
      @book = book
      super("duplicate")
    end
  end

  def self.call(user:, title:, author: nil, **edition)
    Book.transaction do
      Book.connection.execute(Book.sanitize_sql([ "SELECT pg_advisory_xact_lock(hashtext(?))", "add_book:#{user.id}" ]))
      existing = find_duplicate(user, title, author)
      raise Duplicate, existing if existing

      book = user.books.create!(title: title.to_s.squish, author: author.to_s.squish.presence)
      add_edition(book, **edition)
      book
    end
  end

  def self.add_edition(book, format: "unknown", status: "want", source: "manual", store: nil,
    external_id: nil, **dates)
    dates = ReadingDates.parse(dates)
    Book.transaction do
      edition = book.editions.create!(user: book.user, format:, source:, store:,
        external_id: store && external_id)
      reading = edition.create_reading!(user: book.user, status:, status_source: "manual", **dates)
      StatusChange.create!(user: book.user, reading:, to_status: status, source: "manual")
      edition
    end
  end

  def self.find_duplicate(user, title, author)
    key = TextKey.title(title)
    return if key.empty?

    user.books.where(title_key: key).order(:id).find { author.blank? || TextKey.authors(author, it.author) == :same }
  end
end
