class AddBook
  class Duplicate < StandardError
    attr_reader :book

    def initialize(book)
      @book = book
      super("duplicate")
    end
  end

  def self.call(user:, title:, author: nil, format: "unknown", status: "want", source: "manual",
    store: nil, external_id: nil, **dates)
    existing = find_duplicate(user, title, author)
    raise Duplicate, existing if existing

    Book.transaction do
      book = user.books.create!(title: title.to_s.squish, author: author.to_s.squish.presence)
      edition = book.editions.create!(user:, format:, source:, store:, external_id: store && external_id)
      reading = edition.create_reading!(user:, status:, status_source: "manual",
        **dates.slice(:started_at, :finished_at))
      StatusChange.create!(user:, reading:, to_status: status, source: "manual")
      book
    end
  end

  def self.find_duplicate(user, title, author)
    title = normalize(title)
    return if title.empty?

    scope = user.books.where("lower(regexp_replace(trim(title), '\\s+', ' ', 'g')) = ?", title)
    author = normalize(author)
    scope = scope.where("lower(regexp_replace(trim(coalesce(author, '')), '\\s+', ' ', 'g')) = ?", author) if author.present?
    scope.order(:id).first
  end

  def self.normalize(value) = value.to_s.unicode_normalize(:nfc).downcase.squish
end
