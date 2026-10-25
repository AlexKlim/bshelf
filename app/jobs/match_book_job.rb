class MatchBookJob < ApplicationJob
  limits_concurrency to: 1, key: ->(book) { book.user_id }, duration: 5.minutes

  # The book was merged away by a request or another match.
  discard_on ActiveRecord::RecordNotFound

  def perform(book) = BookMatcher.call(book)
end
