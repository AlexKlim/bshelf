require "rails_helper"

RSpec.describe SteelClient do
  it "only accepts a Steel address on the private network" do
    %w[http://steel.railway.internal:3000 http://localhost:3000 http://10.0.0.7:3000 http://[fd12::7]:3000]
      .each { |url| expect { described_class.new(url) }.not_to raise_error, url }

    %w[https://steel.example.com http://93.184.216.34:3000 http://steel.internal.example.com]
      .each { |url| expect { described_class.new(url) }.to raise_error(ArgumentError), url }
  end

  describe "#create_session" do
    let(:client) { described_class.new("http://steel.railway.internal:3000") }
    let(:sessions) { stub_request(:post, "http://steel.railway.internal:3000/v1/sessions") }
    let(:created) { { status: 200, body: { id: "s1", websocketUrl: "ws://x/", debugUrl: "http://x/v1/sessions/debug" }.to_json } }

    before { allow(client).to receive(:sleep) }

    it "waits for a sleeping Steel to wake up" do
      sessions.to_raise(Errno::ECONNREFUSED).then.to_return({ status: 502 }, created)

      expect(client.create_session.id).to eq("s1")
    end

    it "gives up when Steel stays down" do
      stub_const("SteelClient::WAKE", 0)
      sessions.to_return(status: 502)

      expect { client.create_session }.to raise_error(RemoteBrowser::BrowserFailed)
    end
  end

  describe "#cdp" do
    it "hands Ferrum a loopback address piped to Steel, so Chrome sees an IP in Host" do
      steel = TCPServer.new("127.0.0.1", 0)
      client = described_class.new("http://localhost:#{steel.addr[1]}")

      client.cdp("ws://steel.railway.internal:3000/devtools/browser/b1") do |url|
        expect(URI(url)).to have_attributes(host: "127.0.0.1", path: "/devtools/browser/b1")

        ferrum = TCPSocket.new("127.0.0.1", URI(url).port)
        upstream = steel.accept
        ferrum.write("ping")
        expect(upstream.readpartial(4)).to eq("ping")
        upstream.write("pong")
        expect(ferrum.readpartial(4)).to eq("pong")
      end
    ensure
      steel&.close
    end
  end
end
