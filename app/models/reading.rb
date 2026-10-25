class Reading < ApplicationRecord
  STATUSES = %w[want owned in_progress done].freeze
  SOURCES = %w[manual litres kindle_browser kindle_export purchase].freeze

  belongs_to :user
  belongs_to :edition
  has_many :status_changes

  validates :status, inclusion: { in: STATUSES }
  validates :status_source, inclusion: { in: SOURCES }
end
