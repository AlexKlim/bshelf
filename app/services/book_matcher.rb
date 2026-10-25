# Plan D6: only ISBN or original title + author merge on their own; a shared title is a possible duplicate
# for the shelf banner. The older book survives so its id stays stable for the client.
class BookMatcher
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

  def initialize(book)
    @book = book
  end

  # ponytail: compares against every book of the user in Ruby; fine for a few thousand books per user.
  def call
    candidates = DuplicateCandidate.involving(book).to_a
    seen = candidates.to_set { it.other_id(book) }
    dismissed = candidates.select(&:dismissed_at).to_set { it.other_id(book) }

    book.user.books.where.not(id: book.id).order(:id).each do |other|
      next if dismissed.include?(other.id)

      verdict = self.class.verdict(book, other)
      if verdict == :merge
        survivor, absorbed = [ book, other ].sort_by(&:id)
        MergeEvent.merge!(survivor, absorbed)
        return self.class.call(survivor.reload)
      elsif verdict && !seen.include?(other.id)
        DuplicateCandidate.record!(book, other, reason: verdict)
      end
    end
    nil
  end

  def self.verdict(a, b)
    authors = TextKey.authors(a.author, b.author)
    isbn = isbn13(a.isbn)
    return :merge if isbn && isbn == isbn13(b.isbn)
    return :merge if a.original_title.present? && authors == :same &&
      TextKey.title(a.original_title) == TextKey.title(b.original_title)
    return unless TextKey.titles(a.title, a.original_title).intersect?(TextKey.titles(b.title, b.original_title))

    { same: "title_author", unknown: "title" }[authors]
  end
end
