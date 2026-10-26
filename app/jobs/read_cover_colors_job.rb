class ReadCoverColorsJob < ApplicationJob
  BATCH = 50

  def perform
    ids = Book.where.not(cover_url: nil).where(cloth_color: nil).order(Arel.sql("random()")).limit(BATCH).ids
    Rails.logger.info("[covers] reading the colour of #{ids.size} covers") if ids.any?
    ActiveJob.perform_all_later(ids.map { EnrichBookJob.new(it) })
  end
end
