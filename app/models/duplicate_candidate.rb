class DuplicateCandidate < ApplicationRecord
  REASONS = %w[title_author title].freeze

  belongs_to :user
  belongs_to :book
  belongs_to :other_book, class_name: "Book"

  validates :reason, inclusion: { in: REASONS }

  scope :open, -> { where(dismissed_at: nil) }

  def self.involving(book) = where(book_id: book.id).or(where(other_book_id: book.id))

  def self.record!(a, b, reason:, dismissed_at: nil)
    first, second = [ a, b ].sort_by(&:id)
    create_with(user_id: first.user_id, reason:, dismissed_at:).find_or_create_by!(book_id: first.id, other_book_id: second.id)
  end

  def other_id(book) = book_id == book.id ? other_book_id : book_id
end
