class SourceConnection < ApplicationRecord
  KINDS = %w[litres kindle_export kindle_browser].freeze
  STATUSES = %w[never ok error needs_login].freeze

  belongs_to :user

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }

  # Every sync adapter reports here: it is both the Sources screen row and the failure-rate metric.
  def self.record_sync!(user, kind, error: nil, status: error ? "error" : "ok", duration_ms: nil)
    row = user.source_connections.find_or_create_by!(kind:)
    row.update!(status:, error:, **(status == "ok" ? { last_sync_at: Time.current } : {}))
    MetricEvent.record!("sync.#{kind}", outcome: error || "ok", user:, duration_ms:)
    row
  end
end
