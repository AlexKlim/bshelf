class DeviseMailJob < ApplicationJob
  def self.encryptor
    ActiveSupport::MessageEncryptor.new(Rails.application.key_generator.generate_key("devise mail token", 32))
  end

  def self.seal(token) = encryptor.encrypt_and_sign(token, expires_in: 1.day)

  def perform(user, notification, sealed, *args)
    token = self.class.encryptor.decrypt_and_verify(sealed)
    return unless token

    I18n.with_locale(user.locale) { Devise.mailer.public_send(notification, user, token, *args).deliver_now }
  end
end
