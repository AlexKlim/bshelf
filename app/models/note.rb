class Note < ApplicationRecord
  belongs_to :user
  belongs_to :book

  validates :body, presence: true, length: { maximum: 10_000 }
end
