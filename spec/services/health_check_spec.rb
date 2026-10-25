require "rails_helper"

RSpec.describe HealthCheck do
  let(:user) { create(:user) }

  def alerts = described_class.call[:alerts]

  it "raises an alert when most Litres syncs fail" do
    3.times { SourceConnection.record_sync!(user, "litres", error: "timeout") }
    SourceConnection.record_sync!(user, "litres")

    expect(alerts).to include({ alert: "sync_failure_rate", source: "litres", failed: 3, total: 4 })
  end

  it "stays quiet below the sample size or the rate" do
    2.times { SourceConnection.record_sync!(user, "litres", error: "timeout") }
    3.times { SourceConnection.record_sync!(user, "kindle_export") }
    SourceConnection.record_sync!(user, "kindle_export", error: "corrupt")

    expect(alerts).to be_empty
    expect(described_class.call[:summary][:syncs]["kindle_export"]).to include(total: 4, failed: 1)
  end

  it "alerts at once on a changed page or a refused provider" do
    SourceConnection.record_sync!(user, "litres", error: "page_changed")
    SourceConnection.record_sync!(user, "kindle_browser", error: "provider_refused")
    SourceConnection.record_sync!(user, "kindle_export", error: "schema_changed")

    expect(alerts).to contain_exactly(
      { alert: "sync_error", source: "litres", error: "page_changed", count: 1 },
      { alert: "sync_error", source: "kindle_browser", error: "provider_refused", count: 1 }
    )
  end

  it "ignores events outside the last day" do
    travel_to(25.hours.ago) { 4.times { SourceConnection.record_sync!(user, "litres", error: "timeout") } }

    expect(alerts).to be_empty
  end

  it "alerts when share p95 goes over 2 seconds and counts unrecognized shares" do
    18.times { MetricEvent.record!("share", outcome: "listened", duration_ms: 300) }
    MetricEvent.record!("share", outcome: "unrecognized", duration_ms: 2600)
    MetricEvent.record!("share", outcome: "not_found", duration_ms: 2900)

    result = described_class.call
    expect(result[:alerts]).to include(hash_including(alert: "share_slow"))
    expect(result[:summary][:share]).to include(total: 20, unrecognized: 1, not_found: 1)
  end

  it "alerts on failed jobs in the last hour" do
    job = SolidQueue::Job.create!(queue_name: "default", class_name: "HealthCheckJob", arguments: "{}")
    SolidQueue::FailedExecution.create!(job:, error: "boom")

    expect(alerts).to include({ alert: "job_failures", count: 1 })
  end

  describe SourceConnection do
    it "records the sync on the Sources row and as a metric" do
      SourceConnection.record_sync!(user, "litres", error: "needs_login", status: "needs_login")
      row = SourceConnection.record_sync!(user, "litres")

      expect(row.reload).to have_attributes(status: "ok", error: nil, last_sync_at: be_present)
      expect(MetricEvent.where(name: "sync.litres").pluck(:outcome)).to contain_exactly("needs_login", "ok")
    end

    it "asks the person to sign in again when the store rejected the login" do
      %w[needs_login invalid_credentials captcha_required].each do |error|
        row = SourceConnection.record_sync!(user, "litres", error:)
        expect(row).to have_attributes(status: "needs_login", error:)
      end
      expect(SourceConnection.record_sync!(user, "litres", error: "timeout").status).to eq("error")
    end
  end
end

RSpec.describe HealthCheckJob do
  it "logs alerts and drops events older than 30 days" do
    travel_to(31.days.ago) { MetricEvent.record!("share", outcome: "listened") }
    4.times { SourceConnection.record_sync!(create(:user), "litres", error: "timeout") }
    allow(Rails.logger).to receive(:error)

    described_class.perform_now

    expect(Rails.logger).to have_received(:error).with(include('"event":"alert"', '"source":"litres"'))
    expect(MetricEvent.where(created_at: ...30.days.ago)).to be_empty
  end
end
