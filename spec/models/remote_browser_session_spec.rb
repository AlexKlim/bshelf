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
