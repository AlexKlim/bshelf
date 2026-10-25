require "rails_helper"

RSpec.describe LinkResolver do
  subject(:resolver) { described_class.new }

  let(:dns) { Hash.new([ "93.184.216.34" ]) }
  let(:hops) { {} }

  before do
    allow(described_class).to receive(:lookup) { |host, _timeout| dns[host] }
    allow(described_class).to receive(:http_get) { |uri, _ip, _timeout| hops.fetch(uri.to_s) { [ 200, nil ] } }
  end

  it "reads ids straight from store urls without touching the network" do
    expect(resolver.call("https://www.litres.ru/audiobook/stanislav-lem/solyaris-6450429/"))
      .to eq(described_class::Link.new("litres", "6450429"))
    expect(resolver.call("https://www.amazon.de/-/en/Stanislaw-Lem-ebook/dp/b0b7qsv2rk/ref=sr_1_1?x=1"))
      .to eq(described_class::Link.new("amazon", "B0B7QSV2RK"))
    expect(described_class).not_to have_received(:http_get)
  end

  it "follows a short link to the store page" do
    hops["https://a.co/d/3xYz9Q1"] = [ 301, "https://www.amazon.com/dp/0156027607?ref=share" ]

    expect(resolver.call("https://a.co/d/3xYz9Q1")).to eq(described_class::Link.new("amazon", "0156027607"))
  end

  it "returns nil for a store page without a book id" do
    expect(resolver.call("https://www.litres.ru/")).to be_nil
  end

  describe "SSRF protection" do
    it "rejects hosts outside the allowlist before any request" do
      expect { resolver.call("https://evil.example/dp/0156027607") }.to raise_error(described_class::Failed)
      expect { resolver.call("https://amazon.com.evil.example/x") }.to raise_error(described_class::Failed)
      expect(described_class).not_to have_received(:lookup)
    end

    it "rejects ip literals, odd ports, credentials and non-http schemes" do
      %w[http://127.0.0.1/ http://[::1]/ https://a.co:8080/x https://user@a.co/x file:///etc/passwd ftp://a.co/x]
        .each { |url| expect { resolver.call(url) }.to raise_error(described_class::Failed), url }
      expect(described_class).not_to have_received(:http_get)
    end

    it "does not follow a redirect to a private address" do
      hops["https://a.co/d/1"] = [ 302, "http://169.254.169.254/latest/meta-data/" ]

      expect { resolver.call("https://a.co/d/1") }.to raise_error(described_class::Failed, "host not allowed")
      expect(described_class).to have_received(:http_get).once
    end

    it "does not connect when an allowlisted host resolves to a private address" do
      hops["https://a.co/d/1"] = [ 302, "https://amzn.to/rebind" ]
      dns["amzn.to"] = [ "52.94.236.248", "10.0.0.5" ]

      expect { resolver.call("https://a.co/d/1") }.to raise_error(described_class::Failed, "private address")
      expect(described_class).to have_received(:http_get).once
    end

    it "pins the connection to the address it checked" do
      hops["https://a.co/d/1"] = [ 301, "https://www.amazon.com/dp/0156027607" ]
      resolver.call("https://a.co/d/1")

      expect(described_class).to have_received(:http_get).with(URI("https://a.co/d/1"), "93.184.216.34", kind_of(Numeric))
    end

    it "stops after three redirects" do
      hops["https://a.co/1"] = [ 301, "https://a.co/2" ]
      hops["https://a.co/2"] = [ 301, "https://a.co/3" ]
      hops["https://a.co/3"] = [ 301, "https://a.co/4" ]
      hops["https://a.co/4"] = [ 301, "https://a.co/5" ]

      expect { resolver.call("https://a.co/1") }.to raise_error(described_class::Failed, "too many redirects")
    end

    it "gives up when the upstream is slower than the budget" do
      allow(described_class).to receive(:http_get) { sleep 5 }

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      expect { resolver.call("https://a.co/d/1") }.to raise_error(described_class::Failed, "timeout")
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 2
    end

    it "classifies addresses" do
      blocked = %w[10.1.2.3 172.16.0.1 192.168.1.1 127.0.0.1 0.0.0.0 169.254.169.254 100.64.0.1
        ::1 fd12::1 fe80::1 ::ffff:127.0.0.1 ::ffff:10.0.0.1 224.0.0.1 nonsense]
      expect(blocked).to all(satisfy { described_class.blocked_ip?(it) })
      expect(%w[93.184.216.34 2606:4700::1111]).to all(satisfy { !described_class.blocked_ip?(it) })
    end
  end

  describe ".http_get" do
    before { allow(described_class).to receive(:http_get).and_call_original }

    it "connects to the given ip and returns the redirect without reading the body" do
      server = TCPServer.new("127.0.0.1", 0)
      requests = Queue.new
      thread = Thread.new do
        client = server.accept
        requests << client.gets
        nil until client.gets == "\r\n"
        client.write("HTTP/1.1 301 Moved\r\nLocation: https://www.amazon.com/dp/0156027607\r\n" \
          "Content-Length: 100000000\r\n\r\n")
        sleep 3
        client.close
      end
      uri = URI("http://a.co:#{server.addr[1]}/d/1")

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      expect(described_class.http_get(uri, "127.0.0.1", 1)).to eq([ 301, "https://www.amazon.com/dp/0156027607" ])
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 0.5
      expect(requests.pop).to eq("GET /d/1 HTTP/1.1\r\n")
    ensure
      thread&.kill
      thread&.join(1)
      server&.close
    end
  end
end
