require "rails_helper"

RSpec.describe RemoteBrowserSession do
  include ActiveJob::TestHelper

  let(:users) { create_list(:user, 3) }

  it "queues people once the global session limit is reached and promotes them in order" do
    first, second, third = users.map { described_class.start!(it, "kindle") }

    expect(first.status).to eq("connecting")
    expect([ second.queue_position, third.queue_position ]).to eq([ 1, 2 ])
    expect(RemoteBrowserSessionJob).to have_been_enqueued.with(first).once

    first.finish!(interruption: "aborted")

    expect(second.reload.status).to eq("connecting")
    expect(third.reload.queue_position).to eq(1)
    expect(RemoteBrowserSessionJob).to have_been_enqueued.with(second)
  end

  it "returns the running session instead of opening a second one" do
    session = described_class.start!(users.first, "kindle")

    expect(described_class.start!(users.first, "litres")).to eq(session)
    expect(users.first.remote_browser_sessions.count).to eq(1)
  end

  it "frees the slot of a session whose process died" do
    stuck = described_class.start!(users.first, "kindle")
    waiting = described_class.start!(users.second, "kindle")
    stuck.update_columns(updated_at: 16.minutes.ago)

    described_class.dispatch!

    expect(stuck.reload).to have_attributes(status: "interrupted", interruption: "deploy_interrupted")
    expect(waiting.reload.status).to eq("connecting")
  end

  it "recovers a stuck collecting session every minute without any request" do
    stuck = described_class.start!(users.first, "kindle")
    stuck.update_columns(status: "collecting", steel_session_id: "steel-1", updated_at: 16.minutes.ago)
    task = YAML.load_file(Rails.root.join("config/recurring.yml")).dig("production", "remote_browser_dispatch")
    expect(task).to eq("command" => "RemoteBrowserSession.dispatch!", "schedule" => "every minute")

    described_class.dispatch!

    expect(stuck.reload).to have_attributes(status: "interrupted", interruption: "deploy_interrupted")
    expect(steel.released).to eq([ "steel-1" ])
  end

  it "starts a fresh session when the person's last one went stale" do
    stuck = described_class.start!(users.first, "kindle")
    stuck.update_columns(status: "collecting", updated_at: 16.minutes.ago)

    session = described_class.start!(users.first, "kindle")

    expect(session).not_to eq(stuck)
    expect(session.status).to eq("connecting")
    expect(stuck.reload.status).to eq("interrupted")
  end

  it "releases swept browsers and records them only after the dispatch lock is released" do
    stuck = live_session(users.first)
    stuck.update_columns(expires_at: 2.minutes.ago)
    depth = described_class.connection.open_transactions
    seen = []
    allow(RemoteBrowser).to receive(:release) { seen << described_class.connection.open_transactions }
    allow(MetricEvent).to receive(:record!).and_wrap_original do |original, *args, **kwargs|
      seen << described_class.connection.open_transactions
      original.call(*args, **kwargs)
    end

    described_class.dispatch!

    expect(stuck.reload.interruption).to eq("timeout")
    expect(seen).to eq([ depth, depth ])
  end

  it "refuses states the code does not know at the database" do
    session = live_session(users.first)

    row = users.first.source_connections.create!(kind: "litres")
    [ [ session, :status, "paused" ], [ session, :purpose, "audible" ], [ session, :interruption, "crashed" ],
      [ row, :status, "broken" ], [ row, :kind, "goodreads" ] ].each do |record, column, value|
      expect { described_class.transaction(requires_new: true) { record.update_columns(column => value) } }
        .to raise_error(ActiveRecord::CheckViolation), "#{record.class}.#{column}"
    end
  end

  it "uses each viewer token once and only before it expires" do
    session = live_session(users.first)
    token = session.issue_viewer_token!

    expect(session.consume_viewer_token!("wrong")).to be(false)
    expect(session.consume_viewer_token!(token)).to be(true)
    expect(session.consume_viewer_token!(token)).to be(false)

    late = session.issue_viewer_token!
    travel(2.minutes) { expect(session.consume_viewer_token!(late)).to be(false) }
  end
end
