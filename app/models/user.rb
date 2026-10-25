class User < ApplicationRecord
  devise :database_authenticatable, :recoverable, :validatable, :confirmable

  has_many :api_tokens
  has_many :audit_events
  has_many :books
  has_many :editions
  has_many :readings
  has_many :notes
  has_many :highlights
  has_many :source_connections
  has_many :merge_events
  has_many :duplicate_candidates
  has_many :remote_browser_sessions

  def send_devise_notification(notification, *args)
    devise_mailer.send(notification, self, *args).deliver_later
  end
end
