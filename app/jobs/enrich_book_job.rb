class EnrichBookJob < ApplicationJob
  RATE_LIMIT_ATTEMPTS = 6

  # One lookup at a time keeps a large import from bursting the free catalog quotas.
  limits_concurrency to: 1, key: ->(*) { "catalog" }, duration: 5.minutes

  retry_on CatalogClient::Error, wait: :polynomially_longer, attempts: 3
  # The book was merged away by a request while the lookup ran.
  discard_on ActiveRecord::RecordNotFound

  rescue_from CatalogClient::RateLimited do |error|
    raise error if executions >= RATE_LIMIT_ATTEMPTS

    retry_job wait: [ error.retry_after.to_i, 2**executions * 60 ].max
  end

  def perform(book_id)
    book = Book.find_by(id: book_id)
    return unless book

    EnrichBook.call(book)
    MatchBookJob.perform_later(book)
  end
end
