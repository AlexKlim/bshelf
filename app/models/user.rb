class User < ApplicationRecord
  devise :database_authenticatable, :recoverable, :validatable, :confirmable

  has_many :api_tokens
  has_many :audit_events

  def send_devise_notification(notification, *args)
    devise_mailer.send(notification, self, *args).deliver_later
  end
end
