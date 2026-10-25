class RemoteBrowserSession < ApplicationRecord
  PURPOSES = { "kindle" => "kindle_browser", "litres" => "litres" }.freeze
  ACTIVE = %w[queued connecting live collecting].freeze
  RUNNING = %w[connecting live collecting].freeze
  INTERRUPTIONS = %w[aborted timeout provider_refused deploy_interrupted browser_failed].freeze
  SOURCE_ERRORS = { "provider_refused" => "provider_refused", "browser_failed" => "page_changed" }.freeze
  LOGIN_TIME = 5.minutes
  VIEWER_TOKEN_TTL = 1.minute
  STALE_AFTER = 15.minutes
  LOCK_KEY = 0x62736862

  belongs_to :user

  validates :purpose, inclusion: { in: PURPOSES.keys }

  scope :active, -> { where(status: ACTIVE) }

  def self.start!(user, purpose)
    session = user.remote_browser_sessions.active.first || user.remote_browser_sessions.create!(purpose:)
    dispatch!
    session.reload
  rescue ActiveRecord::RecordNotUnique
    user.remote_browser_sessions.active.first!
  end

  # Serialized by an advisory lock, so two requests cannot both take the last free browser.
  def self.dispatch!
    transaction do
      connection.execute("SELECT pg_advisory_xact_lock(#{LOCK_KEY})")
      sweep_stale
      free = RemoteBrowser.max_sessions - where(status: RUNNING).count
      where(status: "queued").order(:id).limit([ free, 0 ].max).each do |session|
        RemoteBrowserSessionJob.perform_later(session) if session.transition!(from: "queued", to: "connecting")
      end
    end
  end

  # A process killed without its stop hook leaves rows that would hold a browser slot forever.
  def self.sweep_stale
    where(status: "live", expires_at: ...1.minute.ago).find_each { it.finish!(interruption: "timeout", dispatch: false) }
    where(status: %w[connecting collecting], updated_at: ...STALE_AFTER.ago)
      .find_each { it.finish!(interruption: "deploy_interrupted", dispatch: false) }
  end

  def self.digest(raw) = OpenSSL::Digest::SHA256.hexdigest(raw)

  def queue_position
    return unless status == "queued"

    self.class.where(status: "queued").where(id: ..id).count
  end

  def seconds_left = status == "live" && expires_at ? [ (expires_at - Time.current).ceil, 0 ].max : nil

  def transition!(from:, to:, **attrs)
    changed = self.class.where(id:, status: from).update_all(status: to, updated_at: Time.current, **attrs) == 1
    reload
    changed
  end

  def finish!(to: "interrupted", interruption: nil, result: nil, from: ACTIVE, dispatch: true)
    return false unless transition!(from:, to:, interruption:, result:, finished_at: Time.current,
      viewer_token_digest: nil)

    RemoteBrowser.release(steel_session_id) if steel_session_id
    outcome = interruption || to
    MetricEvent.record!("remote_browser", outcome:, user:, purpose:, session: uuid)
    AuditEvent.create!(user:, action: "remote_browser_finished", metadata: { session: uuid, purpose:, outcome: })
    if to == "done" || SOURCE_ERRORS.key?(interruption)
      SourceConnection.record_sync!(user, PURPOSES.fetch(purpose), error: SOURCE_ERRORS[interruption])
    end
    self.class.dispatch! if dispatch
    true
  end

  def step_done!(key)
    update!(steps: steps.map { it["key"] == key ? it.merge("state" => "done") : it })
  end

  def issue_viewer_token!
    raw = SecureRandom.base58(32)
    update!(viewer_token_digest: self.class.digest(raw), viewer_token_expires_at: VIEWER_TOKEN_TTL.from_now)
    raw
  end

  def consume_viewer_token!(raw)
    return false if raw.blank?

    self.class.where(id:, status: "live", viewer_token_digest: self.class.digest(raw))
      .where("viewer_token_expires_at > ?", Time.current)
      .update_all(viewer_token_digest: nil) == 1
  end
end
