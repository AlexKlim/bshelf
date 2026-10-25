# Reading dates from API input: `YYYY-MM-DD` or an ISO 8601 timestamp, "" or nil clears the date.
# Tomorrow is allowed because the reader's day can be ahead of the server's.
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
    raise Invalid, field unless value.nil? || [ String, Date, Time ].any? { value.is_a?(it) }
    return if value.blank?

    # Date.iso8601 refuses "2024-02-30", which Time.zone.iso8601 would roll over to March 1.
    Date.iso8601(value[0, 10]) if value.is_a?(String)
    time = value.is_a?(String) ? Time.zone.iso8601(value) : value.in_time_zone
    raise Invalid, field unless time.between?(EARLIEST, Date.current.tomorrow.end_of_day)

    time
  rescue ArgumentError
    raise Invalid, field
  end
end
