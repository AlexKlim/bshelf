# Counts only finished editions by finished_at; a book counts once per year, formats as a breakdown.
class YearStats
  TOP_AUTHORS = 5

  attr_reader :user, :year

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
        id: first[:uuid], title: first[:title], author: first[:author],
        formats: rows.map { it[:format] }.uniq.sort,
        finished_at: rows.map { it[:finished_at] }.max,
        minutes: rows.filter_map { it[:minutes] }.sum.nonzero?
      }
    end.sort_by { it[:finished_at] }
  end

  def finished_by_book
    @finished_by_book ||= user.readings.where(status: "done").joins(edition: :book)
      .pluck("books.id", "books.uuid", "books.title", "books.author", "editions.format",
        "readings.finished_at", "readings.total_minutes")
      .map { |id, uuid, title, author, format, finished_at, minutes| { id:, uuid:, title:, author:, format:, finished_at:, minutes: } }
      .group_by { it[:id] }
  end
end
