# Counts only finished editions by finished_at; a book counts once per year, formats as a breakdown.
class YearStats
  TOP_AUTHORS = 5

  attr_reader :user, :year

  # Listened means an audio edition was finished; read means any other format was. A book can be both.
  def self.counts(books)
    { listened: books.count { it[:formats].include?("audio") }, read: books.count { (it[:formats] - [ "audio" ]).any? } }
  end

  def initialize(user, year)
    @user = user
    @year = year
  end

  def call
    books = in_year
    {
      year:,
      years: finished_by_book.values.flatten.filter_map { it[:finished_at]&.year }.uniq.sort.reverse,
      total: books.size,
      **self.class.counts(books),
      by_format: books.flat_map { it[:formats] }.tally,
      total_minutes: books.filter_map { it[:minutes] }.sum.nonzero?,
      months: (1..12).map { |month| { month:, books: books.select { it[:finished_at].month == month } } },
      no_date_count: finished_by_book.count { |_id, rows| rows.none? { it[:finished_at] } },
      top_authors: books.filter_map { it[:author] }.tally.sort_by { |author, count| [ -count, author ] }
        .first(TOP_AUTHORS).map { |author, count| { author:, count: } }
    }
  end

  private

  def in_year
    finished_by_book.filter_map do |_id, rows|
      rows = rows.select { it[:finished_at]&.year == year }
      next if rows.empty?

      first = rows.first
      {
        id: first[:uuid], title: first[:title], author: first[:author], cloth: first[:cloth] || Cloth.for_uuid(first[:uuid]),
        formats: rows.map { it[:format] }.uniq.sort,
        finished_at: rows.map { it[:finished_at] }.max,
        minutes: rows.filter_map { it[:minutes] }.sum.nonzero?
      }
    end.sort_by { it[:finished_at] }
  end

  def finished_by_book
    @finished_by_book ||= user.readings.where(status: "done").joins(edition: :book)
      .pluck("books.id", "books.uuid", "books.title", "books.author", "books.cloth", "editions.format",
        "readings.finished_at", "readings.total_minutes")
      .map do |id, uuid, title, author, cloth, format, finished_at, minutes|
        { id:, uuid:, title:, author:, cloth:, format:, finished_at:, minutes: }
      end
      .group_by { it[:id] }
  end
end
