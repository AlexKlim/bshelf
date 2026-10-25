# Sends Devise mails in the background without a usable token in solid_queue_jobs: the job arguments
# carry it encrypted with a key derived from secret_key_base.
class DeviseMailJob < ApplicationJob
  def self.encryptor
    ActiveSupport::MessageEncryptor.new(Rails.application.key_generator.generate_key("devise mail token", 32))
  end

  def self.seal(token) = encryptor.encrypt_and_sign(token, expires_in: 1.day)

  def perform(user, notification, sealed, *args)
    token = self.class.encryptor.decrypt_and_verify(sealed)
    Devise.mailer.public_send(notification, user, token, *args).deliver_now if token
  end
end
