require "rails_helper"

RSpec.describe SteelTunnel do
  it "sends the upgrade to Steel and pipes bytes both ways until one side closes" do
    server = TCPServer.new("127.0.0.1", 0)
    client, browser = UNIXSocket.pair
    upstream = TCPSocket.new("127.0.0.1", server.addr[1])
    steel = server.accept

    thread = described_class.open(client, upstream, path: "/v1/sessions/cast?tabInfo=true", host: "steel.internal:3000",
      headers: { "Upgrade" => "websocket", "Sec-WebSocket-Key" => "abc", "Cookie" => "secret" }, ttl: 5)

    request = steel.readpartial(1024)
    expect(request).to start_with("GET /v1/sessions/cast?tabInfo=true HTTP/1.1\r\nHost: steel.internal:3000\r\n")
    expect(request).to include("Upgrade: websocket\r\n", "Sec-WebSocket-Key: abc\r\n")
    expect(request).not_to include("secret")

    browser.write("ping")
    expect(steel.readpartial(4)).to eq("ping")
    steel.write("pong")
    expect(browser.readpartial(4)).to eq("pong")

    steel.close
    expect(thread.join(2)).to be_truthy
    expect(client).to be_closed
  ensure
    server&.close
  end

  it "closes both sides when the sign-in time runs out" do
    server = TCPServer.new("127.0.0.1", 0)
    client, _browser = UNIXSocket.pair
    upstream = TCPSocket.new("127.0.0.1", server.addr[1])
    server.accept

    thread = described_class.open(client, upstream, path: "/v1/sessions/cast", host: "h:1", headers: {}, ttl: 0.2)

    expect(thread.join(2)).to be_truthy
    expect([ client, upstream ]).to all(be_closed)
  ensure
    server&.close
  end
end
