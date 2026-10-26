class FindTranslationsJob < ApplicationJob
  limits_concurrency to: 1, key: ->(user_id) { "translations:#{user_id}" }, duration: 5.minutes
  discard_on ActiveRecord::RecordNotFound

  def perform(user_id)
    return unless JevClient.configured?

    found = TranslationDuplicates.call(User.find(user_id))
    Rails.logger.info("[duplicates] #{found} translated pairs for user #{user_id}") if found.positive?
  rescue JevClient::Error => e
    Rails.logger.warn("[duplicates] jev: #{e.message}")
  end
end
