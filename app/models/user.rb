class User < ApplicationRecord
  devise :database_authenticatable, :recoverable, :validatable, :confirmable

  has_many :api_tokens
  has_many :audit_events
  has_many :books
  has_many :editions
  has_many :discarded_editions
  has_many :readings
  has_many :notes
  has_many :highlights
  has_many :source_connections
  has_many :merge_events
  has_many :duplicate_candidates
  has_many :remote_browser_sessions

  def send_devise_notification(notification, token, *args)
    DeviseMailJob.perform_later(self, notification.to_s, DeviseMailJob.seal(token), *args)
  end

  def revoke_access!
    now = Time.current
    api_tokens.active.update_all(revoked_at: now)
    Doorkeeper::AccessToken.where(resource_owner_id: id, revoked_at: nil).update_all(revoked_at: now)
    Doorkeeper::AccessGrant.where(resource_owner_id: id, revoked_at: nil).update_all(revoked_at: now)
  end
end
