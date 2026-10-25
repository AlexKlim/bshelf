class BookMatcher
  Row = Data.define(:id, :user_id, :title, :original_title, :author, :isbn, :isbn_source)
  NORMALIZED_ISBN = "regexp_replace(upper(coalesce(isbn, '')), '[^0-9X]', '', 'g') IN (:isbns)"
  # Every title key a book matches on (full or core title) starts with the first word of its title or
  # original title, so books starting with other words can never match.
  SAME_FIRST_WORD = "split_part(title_key, ' ', 1) IN (:words) OR split_part(original_title_key, ' ', 1) IN (:words)"

  attr_reader :book

  def self.call(book) = new(book).call

  def self.isbn13(value)
    digits = value.to_s.upcase.delete("^0-9X")
    return digits if digits.match?(/\A97[89]\d{10}\z/)
    return unless digits.match?(/\A\d{9}[\dX]\z/)

    core = "978#{digits[0, 9]}"
    check = (10 - core.chars.each_with_index.sum { |d, i| d.to_i * (i.even? ? 1 : 3) } % 10) % 10
    "#{core}#{check}"
  end

  def self.isbn10(isbn13)
    return unless isbn13&.start_with?("978")

    core = isbn13[3, 9]
    check = (11 - core.chars.each_with_index.sum { |d, i| d.to_i * (10 - i) } % 11) % 11
    "#{core}#{check == 10 ? "X" : check}"
  end

  def initialize(book)
    @book = book
    @isbn = self.class.isbn13(book.isbn)
    @original = TextKey.title(book.original_title)
    @titles = TextKey.titles(book.title, book.original_title)
  end

  def call
    candidates = DuplicateCandidate.involving(book).to_a
    seen = candidates.to_set { it.other_id(book) }
    dismissed = candidates.select(&:dismissed_at).to_set { it.other_id(book) }

    others.each do |other|
      next if dismissed.include?(other.id)

      verdict = verdict(other)
      if verdict == :merge
        survivor, absorbed = Book.where(id: [ book.id, other.id ]).order(:id).to_a
        MergeEvent.merge!(survivor, absorbed)
        return self.class.call(survivor.reload)
      elsif verdict && !seen.include?(other.id)
        DuplicateCandidate.record!(book, other, reason: verdict)
      end
    end
    nil
  end

  private

  def others
    scope = book.user.books.where.not(id: book.id)
    words = [ book.title_key, book.original_title_key ].compact_blank.map { it.split.first }
    matches = scope.where(SAME_FIRST_WORD, words:)
    matches = matches.or(scope.where(NORMALIZED_ISBN, isbns: [ @isbn, self.class.isbn10(@isbn) ].compact)) if @isbn
    matches.order(:id).pluck(*Row.members).map { Row.new(*it) }
  end

  def verdict(other)
    authors = TextKey.authors(book.author, other.author)
    same_isbn = @isbn && @isbn == self.class.isbn13(other.isbn)
    return :merge if same_isbn && [ book, other ].none? { it.isbn_source == "catalog" }
    return :merge if @original.present? && authors == :same && @original == TextKey.title(other.original_title)
    return authors == :same ? "title_author" : "title" if same_isbn
    return unless @titles.intersect?(TextKey.titles(other.title, other.original_title))

    { same: "title_author", unknown: "title" }[authors]
  end
end
