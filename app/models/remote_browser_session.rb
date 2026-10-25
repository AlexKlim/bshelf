class RemoteBrowserSession < ApplicationRecord
  PURPOSES = { "kindle" => "kindle_browser", "litres" => "litres" }.freeze
  ACTIVE = %w[queued connecting live collecting].freeze
  RUNNING = %w[connecting live collecting].freeze
  INTERRUPTIONS = %w[aborted timeout provider_refused deploy_interrupted browser_failed].freeze
  # Interruptions that are the store's doing and so mark its source as failing. A broken browser is ours.
  SOURCE_ERRORS = { "provider_refused" => "provider_refused" }.freeze
  LOGIN_TIME = 5.minutes
  VIEWER_TOKEN_TTL = 1.minute
  STALE_AFTER = 15.minutes
  LOCK_KEY = 0x62736862

  belongs_to :user

  validates :purpose, inclusion: { in: PURPOSES.keys }

  scope :active, -> { where(status: ACTIVE) }

  def self.start!(user, purpose)
    dispatch!
    session = user.remote_browser_sessions.active.first || user.remote_browser_sessions.create!(purpose:)
    dispatch!
    session.reload
  rescue ActiveRecord::RecordNotUnique
    user.remote_browser_sessions.active.first!
  end

  def self.dispatch!
    swept = transaction do
      connection.execute("SELECT pg_advisory_xact_lock(#{LOCK_KEY})")
      stale = sweep_stale
      free = RemoteBrowser.max_sessions - where(status: RUNNING).count
      where(status: "queued").order(:id).limit([ free, 0 ].max).each do |session|
        RemoteBrowserSessionJob.perform_later(session) if session.transition!(from: "queued", to: "connecting")
      end
      stale
    end
    swept.each(&:finished)
  end

  def self.sweep_stale
    timed_out = where(status: "live", expires_at: ...1.minute.ago).map { [ it, "timeout" ] }
    dead = where(status: %w[connecting collecting], updated_at: ...STALE_AFTER.ago).map { [ it, "deploy_interrupted" ] }
    (timed_out + dead).select { |session, interruption| session.end!(from: session.status, interruption:) }.map(&:first)
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

  def finish!(to: "interrupted", interruption: nil, result: nil, from: ACTIVE, source_error: SOURCE_ERRORS[interruption])
    return false unless end!(from:, to:, interruption:, result:)

    finished(source_error:)
    self.class.dispatch!
    true
  end

  def end!(from:, to: "interrupted", interruption: nil, result: nil)
    transition!(from:, to:, interruption:, result:, finished_at: Time.current, viewer_token_digest: nil)
  end

  def finished(source_error: SOURCE_ERRORS[interruption])
    RemoteBrowser.release(steel_session_id) if steel_session_id
    outcome = interruption || status
    MetricEvent.record!("remote_browser", outcome:, user:, purpose:, session: uuid)
    AuditEvent.create!(user:, action: "remote_browser_finished", metadata: { session: uuid, purpose:, outcome: })
    SourceConnection.record_sync!(user, PURPOSES.fetch(purpose), error: source_error) if status == "done" || source_error
  end

  def step_done!(key)
    update!(steps: steps.map { it["key"] == key ? it.merge("state" => "done") : it })
  end

  def heartbeat! = self.class.where(id:, status: "collecting").update_all(updated_at: Time.current)

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
