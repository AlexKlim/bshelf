require "rails_helper"

RSpec.describe RemoteBrowserSessionJob do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:session) { RemoteBrowserSession.start!(user, "kindle") }

  def tick! = described_class.perform_now(session.reload)

  it "connects a Steel browser and starts the 5 minute sign-in timer" do
    tick!

    expect(session.reload).to have_attributes(status: "live", steel_session_id: steel.created.last,
      viewer_path: "v1/sessions/debug", websocket_url: "ws://steel.fake/devtools")
    expect(session.seconds_left).to be_within(2).of(300)
  end

  it "keeps ticking while the person signs in" do
    collector.login_delay = 1.minute
    tick!

    expect { tick! }.to have_enqueued_job(described_class).with(session)
    expect(session.reload.status).to eq("live")
  end

  it "collects with steps and finishes with the result" do
    tick!
    seen = []
    allow(collector).to receive(:collect).and_wrap_original do |original, s, &block|
      original.call(s) do |step|
        block.call(step)
        seen << s.reload.steps
      end
    end

    tick!

    expect(seen.first).to eq([ { "key" => "library", "state" => "done" }, { "key" => "highlights", "state" => "pending" } ])
    expect(session.reload).to have_attributes(status: "done", result: { "books" => 12, "highlights" => 40 },
      finished_at: be_present)
    expect(steel.released).to eq([ session.steel_session_id ])
    expect(user.source_connections.find_by(kind: "kindle_browser")).to have_attributes(status: "ok", last_sync_at: be_present)
    expect(MetricEvent.where(name: "remote_browser").pluck(:outcome)).to eq([ "done" ])
    expect(AuditEvent.where(user:, action: "remote_browser_finished").count).to eq(1)
  end

  it "times out after 5 minutes of sign-in" do
    collector.login_delay = 1.hour
    tick!

    travel(RemoteBrowserSession::LOGIN_TIME + 1.second) { tick! }

    expect(session.reload).to have_attributes(status: "interrupted", interruption: "timeout")
    expect(steel.released).to eq([ session.steel_session_id ])
    expect(user.source_connections).to be_empty
  end

  it "reports a provider that refuses the sign-in" do
    tick!
    allow(collector).to receive(:logged_in?).and_raise(RemoteBrowser::ProviderRefused)

    tick!

    expect(session.reload).to have_attributes(status: "interrupted", interruption: "provider_refused")
    expect(user.source_connections.find_by(kind: "kindle_browser")).to have_attributes(status: "error", error: "provider_refused")
  end

  it "reports a changed page during collection without saving a partial result" do
    tick!
    allow(collector).to receive(:collect).and_raise(RemoteBrowser::PageChanged)

    tick!

    expect(session.reload).to have_attributes(status: "interrupted", interruption: "browser_failed", result: nil)
    expect(user.source_connections.find_by(kind: "kindle_browser").error).to eq("page_changed")
  end

  it "marks the session interrupted and re-raises unexpected errors" do
    tick!
    allow(collector).to receive(:collect).and_raise(NoMethodError)

    expect { tick! }.to raise_error(NoMethodError)
    expect(session.reload.interruption).to eq("browser_failed")
  end

  it "drops the result when the person aborted during collection" do
    tick!
    allow(collector).to receive(:collect) do |s|
      s.finish!(interruption: "aborted")
      { books: 1, highlights: 0 }
    end

    tick!

    expect(session.reload).to have_attributes(interruption: "aborted", result: nil)
    expect(steel.released.size).to eq(1)
  end

  it "marks a collecting session interrupted when a deploy stops the worker" do
    tick!
    allow(collector).to receive(:collect) do
      RemoteBrowser.interrupt_running!
      { books: 3, highlights: 0 }
    end

    tick!

    expect(session.reload).to have_attributes(status: "interrupted", interruption: "deploy_interrupted", result: nil)
    expect(RemoteBrowser.running).to be_empty
  end

  it "leaves live sessions alone on a deploy, they carry on in the next process" do
    tick!
    RemoteBrowser.interrupt_running!

    expect(session.reload.status).to eq("live")
  end

  it "fails cleanly when Steel is down without blaming the store" do
    allow(steel).to receive(:create_session).and_raise(RemoteBrowser::BrowserFailed)

    tick!

    expect(session.reload).to have_attributes(status: "interrupted", interruption: "browser_failed")
    expect(user.source_connections).to be_empty
  end

  it "releases the new browser when the person aborted while it was connecting" do
    allow(steel).to receive(:create_session).and_wrap_original do |original|
      session.finish!(interruption: "aborted")
      original.call
    end

    tick!

    expect(session.reload).to have_attributes(status: "interrupted", interruption: "aborted", steel_session_id: nil)
    expect(steel.released).to eq(steel.created)
    expect(steel.created.size).to eq(1)
  end

  it "keeps a long collection alive while the collector reports progress" do
    tick!
    allow(collector).to receive(:collect) do |s, &progress|
      travel(10.minutes)
      progress.call(nil)
      travel(10.minutes)
      RemoteBrowserSession.dispatch!
      expect(s.reload.status).to eq("collecting")
      { books: 1, highlights: 0 }
    end

    tick!

    expect(session.reload.status).to eq("done")
  ensure
    travel_back
  end

  it "drops a queued tick whose session was deleted with its account" do
    tick!
    user.destroy!

    expect { perform_enqueued_jobs }.not_to raise_error
  end

  it "does nothing for a session that already ended" do
    session.finish!(interruption: "aborted")

    tick!

    expect(steel.created).to be_empty
  end
end
