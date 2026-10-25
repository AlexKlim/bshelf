class HealthCheckJob < ApplicationJob
  RETENTION = 30.days

  def perform
    result = HealthCheck.call
    Rails.logger.info({ event: "metrics.summary", **result[:summary] }.to_json)
    result[:alerts].each { Rails.logger.error({ event: "alert", **it }.to_json) }
    MetricEvent.where(created_at: ...RETENTION.ago).in_batches.delete_all
  end
end
