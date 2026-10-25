class MetricEvent < ApplicationRecord
  belongs_to :user, optional: true

  def self.record!(name, outcome:, user: nil, duration_ms: nil, **context)
    Rails.logger.info({ event: name, outcome:, user_id: user&.id, duration_ms:, **context }.compact.to_json)
    create!(name:, outcome:, user:, duration_ms:)
  end

  def self.measure
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = yield
    [ result, ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round ]
  end
end
