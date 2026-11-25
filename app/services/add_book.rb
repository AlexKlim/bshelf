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
    external_id: nil, status_source: "manual", **dates)
    dates = ReadingDates.parse(dates)
    Book.transaction do
      edition = book.editions.create!(user: book.user, format:, source:, store:,
        external_id: store && external_id)
      reading = edition.create_reading!(user: book.user, status:, status_source:, **dates)
      StatusChange.create!(user: book.user, reading:, to_status: status, source: status_source)
      edition
    end
  end

  def self.record(book, status:, format:, source:, finished_at: nil)
    return if status == "want"

    rank = StatusResolver::STATUS_RANK
    book.with_lock do
      editions = book.editions.includes(:reading).order(:id).to_a
      edition = editions.find { it.format == format } || editions.find do
        format == "unknown" || it.format == "unknown" || (it.store.nil? && it.reading&.status == "want")
      end
      next add_edition(book, status:, format:, source:, finished_at:) unless edition
      next if rank[status] <= rank.fetch(edition.reading&.status, -1)

      edition.update!(format:) unless format == "unknown"
      reading = edition.reading || edition.create_reading!(user: book.user, status: "want", status_source: "manual")
      StatusResolver.manual!(reading, status:, **ReadingDates.parse(finished_at:).compact)
      edition
    end
  end

  def self.find_duplicate(user, title, author)
    key = TextKey.title(title)
    return if key.empty?

    # ponytail: compares every book of the user in Ruby, fine for shelves of a few thousand books
    matches = user.books.order(:id).select do
      TextKey.same_title?(title, it.title) && (author.blank? || TextKey.authors(author, it.author) != :different)
    end
    matches.find { it.title_key == key } || matches.first
  end
end
