require "rails_helper"

RSpec.describe ClientMetadataDocument do
  let(:client_id) { "https://claude.ai/oauth/mcp-client-metadata" }
  let(:callback) { "https://claude.ai/api/mcp/auth_callback" }
  let(:document) { { client_id:, redirect_uris: [ callback ] }.to_json }

  before { allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new) }

  it "does not fetch a failing client_id again for a few minutes" do
    fetcher = instance_double(Doorkeeper::HttpFetcher)
    allow(Doorkeeper::HttpFetcher).to receive(:new).and_return(fetcher)
    allow(fetcher).to receive(:fetch).and_raise(Doorkeeper::HttpFetcher::FetchError, "boom")

    2.times { expect(described_class.resolve(client_id)).to be_nil }
    expect(fetcher).to have_received(:fetch).once

    travel(described_class::FAILURE_TTL + 1.second) { described_class.resolve(client_id) }
    expect(fetcher).to have_received(:fetch).twice
  end

  it "returns the application another request created while this one fetched" do
    allow_any_instance_of(Doorkeeper::HttpFetcher).to receive(:fetch) do
      Doorkeeper::Application.create!(uid: client_id, name: "claude.ai", redirect_uri: callback, confidential: false)
      document
    end

    app = described_class.resolve(client_id)

    expect(app).to be_persisted
    expect(Doorkeeper::Application.where(uid: client_id).count).to eq(1)
  end
end
