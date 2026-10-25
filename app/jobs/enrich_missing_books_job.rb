# Picks up books whose lookup ran out of retries, usually after a day of exhausted catalog quota.
class EnrichMissingBooksJob < ApplicationJob
  BATCH = 500

  def perform
    ids = Book.where(enriched_at: nil).where(created_at: ...1.hour.ago).order(:id).limit(BATCH).ids
    ActiveJob.perform_all_later(ids.map { EnrichBookJob.new(it) })
  end
end
