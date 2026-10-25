class Book < ApplicationRecord
  belongs_to :user
  has_many :editions
  has_many :readings, through: :editions
  has_many :highlights
  has_many :notes

  validates :title, presence: true, length: { maximum: 500 }
  validates :author, length: { maximum: 500 }
end
