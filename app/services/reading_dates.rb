# Reading dates from API input: `YYYY-MM-DD` or an ISO 8601 timestamp, "" or nil clears the date.
module ReadingDates
  FIELDS = %i[started_at finished_at].freeze
  EARLIEST = Time.utc(1900)

  class Invalid < StandardError
    attr_reader :field

    def initialize(field)
      @field = field
      super("invalid #{field}")
    end
  end

  def self.parse(dates)
    dates.to_h.symbolize_keys.slice(*FIELDS).to_h { |field, value| [ field, cast(field, value) ] }
  end

  def self.cast(field, value)
    return if value.blank?

    # Date.iso8601 refuses "2024-02-30", which Time.zone.iso8601 would roll over to March 1.
    Date.iso8601(value[0, 10]) if value.is_a?(String)
    time = value.is_a?(String) ? Time.zone.iso8601(value) : value.in_time_zone
    raise Invalid, field unless time.between?(EARLIEST, Time.current.next_year.end_of_year)

    time
  rescue ArgumentError
    raise Invalid, field
  end
end
