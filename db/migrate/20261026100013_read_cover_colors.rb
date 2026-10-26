class ReadCoverColors < ActiveRecord::Migration[8.1]
  def up
    Book.where.not(cover_url: nil).where(cloth_color: nil).pluck(:id).each { EnrichBookJob.perform_later(it) }
  end

  def down; end
end
