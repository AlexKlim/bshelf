class ApiToken < ApplicationRecord
  PREFIX = "bsh_"

  belongs_to :user

  validates :name, presence: true, length: { maximum: 100 }

  scope :active, -> { where(revoked_at: nil) }

  def self.issue!(user:, name:)
    raw = "#{PREFIX}#{SecureRandom.base58(32)}"
    [ user.api_tokens.create!(name:, token_digest: digest(raw)), raw ]
  end

  def self.authenticate(raw)
    return if raw.blank?

    token = active.includes(:user).find_by(token_digest: digest(raw))
    token.touch(:last_used_at) if token && (token.last_used_at.nil? || token.last_used_at < 1.hour.ago)
    token
  end

  def self.digest(raw) = OpenSSL::Digest::SHA256.hexdigest(raw)

  def revoke! = update!(revoked_at: Time.current)
end
