class BookGenresJob < ApplicationJob
  limits_concurrency to: 1, key: ->(user_id) { "genres:#{user_id}" }, duration: 5.minutes
  discard_on ActiveRecord::RecordNotFound

  def perform(user_id)
    return unless JevClient.configured?

    BookGenres.call(User.find(user_id))
  rescue JevClient::Error => e
    Rails.logger.warn("[genres] jev: #{e.message}")
  end
end
