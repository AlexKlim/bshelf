class Book < ApplicationRecord
  GENRES = {
    "fiction" => "Literary and general fiction, classics, romance, poetry",
    "fantasy" => "Science fiction and fantasy",
    "crime" => "Mystery, crime, detective stories and thrillers",
    "psychology" => "Psychology, self-help, personal growth, relationships, health",
    "business" => "Business, management, economics, money, careers",
    "science" => "Popular science, technology, programming, philosophy",
    "history" => "History, biographies, memoirs, politics",
    "other" => "Anything else: children's books, religion, travel, cooking, hobbies"
  }.freeze

  belongs_to :user
  has_many :editions
  has_many :readings, through: :editions
  has_many :highlights
  has_many :notes
  has_many :merge_events

  normalizes :title, :author, :original_title, with: -> { it.delete("\u0301") }
  validates :title, presence: true, length: { maximum: 500 }
  validates :author, length: { maximum: 500 }
  validates :genre, inclusion: { in: GENRES.keys }, allow_nil: true

  before_save do
    if cover_url_changed?
      self.cloth = nil unless cloth_changed?
      self.cloth_color = nil unless cloth_color_changed?
    end
  end
  # Duplicate checks look titles up by these keys, so they follow the matcher's TextKey rule.
  before_save do
    self.title_key = TextKey.title(title)
    self.original_title_key = TextKey.title(original_title)
  end
  after_create_commit :enrich_later
  after_update_commit -> { enrich_later if saved_change_to_cover_url? && (cloth.nil? || cloth_color.nil?) }

  def enrich_later = EnrichBookJob.perform_later(id)

  def discard!
    transaction do
      editions.where.not(store: nil).where.not(external_id: nil).each do
        user.discarded_editions.find_or_create_by!(store: it.store, external_id: it.external_id)
      end
      destroy!
    end
  end
end
