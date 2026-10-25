# Picks up books whose lookup ran out of retries, usually after a day of exhausted catalog quota.
class EnrichMissingBooksJob < ApplicationJob
  BATCH = 500

  def perform
    Book.where(enriched_at: nil).where(created_at: ...1.hour.ago).order(:id).limit(BATCH).ids
      .each { EnrichBookJob.perform_later(it) }
  end
end
