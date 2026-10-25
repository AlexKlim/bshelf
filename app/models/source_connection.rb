class SourceConnection < ApplicationRecord
  KINDS = %w[litres kindle_export kindle_browser].freeze
  STATUSES = %w[never ok error needs_login].freeze

  belongs_to :user

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
end
