class Book < ApplicationRecord
  belongs_to :user
  has_many :editions
  has_many :readings, through: :editions
  has_many :highlights
  has_many :notes
  has_many :merge_events

  validates :title, presence: true, length: { maximum: 500 }
  validates :author, length: { maximum: 500 }

  before_save { self.cloth = self.cloth_color = nil if cover_url_changed? && !cloth_changed? && !cloth_color_changed? }
  # Duplicate checks look titles up by these keys, so they follow the matcher's TextKey rule.
  before_save do
    self.title_key = TextKey.title(title)
    self.original_title_key = TextKey.title(original_title)
  end
  after_create_commit :enrich_later
  after_update_commit -> { enrich_later if saved_change_to_cover_url? && cloth.nil? }

  def enrich_later = EnrichBookJob.perform_later(id)
end
