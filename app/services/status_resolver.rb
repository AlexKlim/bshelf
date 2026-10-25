# Background jobs never read-then-write a status: the decision lives in the WHERE clause of one
# UPDATE, so a manual edit that lands between a job's read and its write always wins.
class StatusResolver
  STATUS_RANK = { "want" => 0, "owned" => 1, "in_progress" => 2, "done" => 3 }.freeze
  SOURCE_RANK = { "purchase" => 0, "kindle_export" => 1, "kindle_browser" => 2, "litres" => 3, "manual" => 4 }.freeze
  DATE_FIELDS = %i[started_at finished_at total_minutes].freeze

  # A person who marks a book finished (or started) without a date means today; a stored date or an
  # explicit empty value wins.
  DEFAULT_DATE = { "done" => :finished_at, "in_progress" => :started_at }.freeze

  def self.manual!(reading, status:, **dates)
    field = DEFAULT_DATE[status]
    dates[field] = Time.current if field && reading.status != status && !dates.key?(field) && reading[field].nil?
    new(reading).apply(status:, source: "manual", **dates)
  end

  def self.automatic!(reading, status:, source:, **dates)
    raise ArgumentError, "manual is not an automatic source" if source == "manual"

    new(reading).apply(status:, source:, **dates)
  end

  attr_reader :reading

  def initialize(reading)
    @reading = reading
  end

  # Manual writes set exactly the date fields passed (nil clears). Automatic writes only fill
  # what they know and never touch a manual row, a stronger source, or a later status,
  # except a purchase moving "want" to "owned".
  def apply(status:, source:, **dates)
    raise ArgumentError, "unknown status #{status}" unless STATUS_RANK.key?(status)

    manual = source == "manual"
    sets = [ "status = :status", "status_source = :source", "updated_at = now()" ]
    DATE_FIELDS.each do |field|
      next unless dates.key?(field)

      sets << (manual ? "#{field} = :#{field}" : "#{field} = COALESCE(:#{field}, readings.#{field})")
    end

    sql = <<~SQL
      WITH old AS (SELECT id, status FROM readings WHERE id = :id FOR UPDATE)
      UPDATE readings SET #{sets.join(", ")}
      FROM old
      WHERE readings.id = old.id AND (#{manual ? "TRUE" : automatic_guard})
      RETURNING old.status
    SQL
    binds = { id: reading.id, status:, source:, status_rank: STATUS_RANK[status], source_rank: SOURCE_RANK[source] }

    Reading.transaction do
      old_status = Reading.connection.select_value(Reading.sanitize_sql([ sql, binds.merge(dates.slice(*DATE_FIELDS)) ]))
      next false unless old_status

      StatusChange.create!(user_id: reading.user_id, reading_id: reading.id,
        from_status: old_status, to_status: status, source:)
      true
    end.tap { reading.reload }
  end

  private

  def automatic_guard
    <<~SQL.squish
      (readings.status_source <> 'manual'
        AND #{rank_case("readings.status_source", SOURCE_RANK)} <= :source_rank
        AND #{rank_case("readings.status", STATUS_RANK)} <= :status_rank)
      OR (readings.status = 'want' AND :status = 'owned')
    SQL
  end

  def rank_case(column, ranks)
    "CASE #{column} #{ranks.map { |key, rank| "WHEN '#{key}' THEN #{rank}" }.join(" ")} END"
  end
end
