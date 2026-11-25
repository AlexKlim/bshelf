class Edition < ApplicationRecord
  FORMATS = %w[audio ebook personal_doc unknown].freeze
  STORES = %w[litres amazon storytel].freeze
  SOURCES = %w[manual share mcp litres kindle_export kindle_browser storytel].freeze

  belongs_to :user
  belongs_to :book
  has_one :reading

  validates :format, inclusion: { in: FORMATS }
  validates :store, inclusion: { in: STORES }, allow_nil: true
  validates :source, inclusion: { in: SOURCES }

  def discard!
    transaction do
      user.discarded_editions.find_or_create_by!(store:, external_id:) if store && external_id
      destroy!
    end
  end
end
