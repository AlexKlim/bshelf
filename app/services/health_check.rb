# Section 8 signals over the last day. Alerts are structured error log lines (event "alert"),
# so whatever reads the logs (Railway log alerts today) pages the operator; no email (eng D5).
class HealthCheck
  WINDOW = 24.hours
  MIN_SYNCS = 4
  SYNC_FAILURE_RATE = 0.5
  SHARE_P95_MS = 2000
  ALERT_ERRORS = %w[schema_changed page_changed provider_refused].freeze

  def self.call(now: Time.current) = new(now).call

  def initialize(now)
    @now = now
    @alerts = []
  end

  def call
    summary = { syncs: syncs, share: share, remote_browser: remote_browser, failed_jobs: failed_jobs }
    { summary:, alerts: @alerts }
  end

  private

  def events(name) = MetricEvent.where(name:, created_at: (@now - WINDOW)..@now)

  def syncs
    SourceConnection::KINDS.to_h do |kind|
      outcomes = events("sync.#{kind}").group(:outcome).count
      total = outcomes.values.sum
      failed = total - outcomes.fetch("ok", 0)
      alert(:sync_failure_rate, source: kind, failed:, total:) if total >= MIN_SYNCS && failed > total * SYNC_FAILURE_RATE
      (outcomes.keys & ALERT_ERRORS).each { alert(:sync_error, source: kind, error: it, count: outcomes[it]) }
      [ kind, { total:, failed:, outcomes: } ]
    end
  end

  def share
    scope = events("share")
    p95 = scope.pick(Arel.sql("percentile_cont(0.95) WITHIN GROUP (ORDER BY duration_ms)"))&.round
    alert(:share_slow, p95_ms: p95) if p95 && p95 > SHARE_P95_MS
    outcomes = scope.group(:outcome).count
    { total: outcomes.values.sum, p95_ms: p95, unrecognized: outcomes.fetch("unrecognized", 0),
      not_found: outcomes.fetch("not_found", 0) }
  end

  def remote_browser
    events("remote_browser").group(:outcome).count
  end

  def failed_jobs
    count = SolidQueue::FailedExecution.where(created_at: (@now - 1.hour)..@now).count
    alert(:job_failures, count:) if count.positive?
    count
  end

  def alert(name, **details) = @alerts << { alert: name.to_s, **details }
end
