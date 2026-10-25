class ShelfSearch
  LIMIT = 20

  attr_reader :user, :query

  def initialize(user, query)
    @user = user
    @query = query.to_s.squish
  end

  def call = result(matches)

  def result(books)
    exact = books.select { AddBook.normalize(it.title) == AddBook.normalize(query) }
    books = exact if exact.one?
    { query:, answer: answer(books), books: Shelf.new(user).summaries(books.map(&:id)) }
  end

  private

  def matches
    return [] if query.empty?

    like = "%#{Book.sanitize_sql_like(query)}%"
    by_text = user.books.where("title ILIKE :like OR author ILIKE :like OR original_title ILIKE :like", like:)
    by_id = user.books.where(isbn: query)
      .or(user.books.where(id: user.editions.where(external_id: query).select(:book_id)))
    user.books.where(id: by_text.select(:id)).or(user.books.where(id: by_id.select(:id)))
      .includes(editions: :reading).order(:title).limit(LIMIT).to_a
  end

  def answer(books)
    return { kind: "not_found" } if books.empty?
    return { kind: "similar", count: books.size } if books.size > 1

    book = books.first
    readings = book.editions.filter_map(&:reading)
    done = book.editions.select { it.reading&.status == "done" }.map(&:format)
    kind =
      if done.include?("audio") && (done - [ "audio" ]).any? then "read_and_listened"
      elsif done.include?("audio") then "listened"
      elsif done.any? then "read"
      elsif readings.any? { it.status == "in_progress" } then "in_progress"
      elsif readings.any? { it.status == "owned" } then "owned"
      else "want"
      end
    { kind:, book_id: book.uuid }
  end
end
