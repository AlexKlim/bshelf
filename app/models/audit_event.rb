class AuditEvent < ApplicationRecord
  ACTIONS = %w[
    sign_up email_confirmed sign_in sign_in_failed sign_out
    password_reset_requested password_reset
    api_token_created api_token_revoked account_deleted
    remote_browser_started remote_browser_finished
  ].freeze

  belongs_to :user, optional: true

  validates :action, inclusion: { in: ACTIONS }

  def self.record!(action, request:, user: nil, **metadata)
    create!(action:, user:, ip: request.remote_ip, metadata:)
  end
end
