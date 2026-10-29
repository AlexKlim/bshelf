class SourceConnection < ApplicationRecord
  KINDS = %w[litres kindle_export kindle_browser storytel].freeze
  STATUSES = %w[never ok error needs_login].freeze
  # Errors only the person can fix by signing in again; the Sources row asks for that instead of a retry.
  LOGIN_ERRORS = %w[needs_login invalid_credentials captcha_required].freeze

  belongs_to :user

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }

  def self.record_sync!(user, kind, error: nil, status: sync_status(error), duration_ms: nil)
    row = user.source_connections.find_or_create_by!(kind:)
    row.update!(status:, error:, **(status == "ok" ? { last_sync_at: Time.current } : {}))
    MetricEvent.record!("sync.#{kind}", outcome: error || "ok", user:, duration_ms:)
    row
  end

  def self.sync_status(error)
    if error.nil? then "ok"
    elsif LOGIN_ERRORS.include?(error) then "needs_login"
    else "error"
    end
  end
end
