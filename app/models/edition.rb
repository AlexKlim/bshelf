class Edition < ApplicationRecord
  FORMATS = %w[audio ebook personal_doc unknown].freeze
  STORES = %w[litres amazon].freeze
  SOURCES = %w[manual share mcp litres kindle_export kindle_browser].freeze

  belongs_to :user
  belongs_to :book
  has_one :reading

  validates :format, inclusion: { in: FORMATS }
  validates :store, inclusion: { in: STORES }, allow_nil: true
  validates :source, inclusion: { in: SOURCES }
end
