class ShelfMove
  KEYS = %w[now want owned no_date].freeze

  def self.key?(key) = KEYS.include?(key) || (key.match?(/\A\d{4}\z/) && key.to_i.between?(1900, Date.current.year))

  def self.call(book, key:, before: nil, after: nil) = new(book).call(key:, before:, after:)

  attr_reader :book

  def initialize(book)
    @book = book
  end

  def call(key:, before:, after:)
    shelf = Shelf.new(book.user)
    places = shelf.placements([ before, after ].compact.map(&:id))
    newer, older = places[before&.id], places[after&.id]
    finished = finished_at(key.to_i, newer&.finished_at, older&.finished_at) if key.match?(/\A\d+\z/)

    Book.transaction do
      book.editions.includes(:reading).each do |edition|
        status, dates = target(edition, key, finished)
        reading = edition.reading || edition.create_reading!(user: book.user, status:, status_source: "manual")
        StatusResolver.manual!(reading, status:, **dates)
      end
      book.update_columns(shelved_key: shelf.key_for(book), shelved_at: between(newer&.activity_at, older&.activity_at))
    end
  end

  private

  def target(edition, key, finished)
    case key
    when "now" then [ "in_progress", {} ]
    when "want", "owned" then [ edition.store ? "owned" : "want", {} ]
    when "no_date" then [ "done", { finished_at: nil } ]
    else [ "done", { finished_at: finished } ]
    end
  end

  def finished_at(year, newer, older)
    first = Time.zone.local(year)
    last = [ first.end_of_year, Time.current ].min
    time = if newer && older then older + (newer - older) / 2
    elsif newer then newer - 1.day
    elsif older then older + 1.day
    else last
    end
    time.clamp(first, last)
  end

  def between(newer, older)
    return older + (newer - older) / 2 if newer && older
    return newer - 1.second if newer

    Time.current
  end
end
