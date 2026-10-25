class Shelf
  Placement = Data.define(:key, :finished_at, :activity_at)

  attr_reader :user

  def initialize(user)
    @user = user
  end

  def placements(book_ids = nil)
    scope = user.books.left_joins(editions: :reading).group("books.id")
    scope = scope.where(id: book_ids) if book_ids
    scope.pluck(
      "books.id",
      Arel.sql(<<~SQL.squish),
        CASE
          WHEN bool_or(readings.status = 'in_progress') THEN 'now'
          WHEN bool_or(readings.status = 'done') THEN COALESCE(
            (EXTRACT(YEAR FROM max(readings.finished_at) FILTER (WHERE readings.status = 'done'))::int)::text,
            'no_date')
          WHEN bool_or(readings.status = 'owned') THEN 'owned'
          ELSE 'want'
        END
      SQL
      Arel.sql("max(readings.finished_at) FILTER (WHERE readings.status = 'done')"),
      Arel.sql("COALESCE(max(readings.updated_at), books.created_at)")
    ).to_h { |id, key, finished_at, activity_at| [ id, Placement.new(key:, finished_at:, activity_at:) ] }
  end

  def key_for(book) = placements([ book.id ]).fetch(book.id).key

  def shelves(limit:)
    grouped.map do |key, ids|
      { key:, count: ids.size, books: summaries(ids.first(limit)) }
    end
  end

  def page(key, offset:, limit:)
    ids = grouped.fetch(key, [])
    { key:, count: ids.size, books: summaries(ids.drop(offset).first(limit)) }
  end

  def summaries(ids)
    return [] if ids.empty?

    places = placements(ids)
    books = user.books.where(id: ids).includes(editions: :reading).index_by(&:id)
    ids.map { |id| BookSerializer.summary(books[id], places[id].key) }
  end

  private

  # ponytail: places every book on each request; fine for a few thousand books per user.
  def grouped
    placements
      .group_by { |_id, place| place.key }
      .sort_by { |key, _| shelf_rank(key) }
      .to_h { |key, rows| [ key, sort_rows(key, rows).map(&:first) ] }
  end

  def sort_rows(key, rows)
    rows.sort_by { |id, place| [ -(year?(key) ? place.finished_at : place.activity_at).to_f, -id ] }
  end

  def shelf_rank(key)
    case key
    when "now" then [ 0, 0 ]
    when "want" then [ 1, 0 ]
    when "owned" then [ 2, 0 ]
    when "no_date" then [ 4, 0 ]
    else [ 3, -key.to_i ]
    end
  end

  def year?(key) = key.match?(/\A\d+\z/)
end
