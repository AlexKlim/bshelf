require "net/http"

class SteelClient
  Session = Data.define(:id, :websocket_url, :viewer_path)
  TIMEOUT = 5
  WAKE = 60

  def self.private_host?(host)
    host = host.to_s.downcase
    return true if host == "localhost" || host.end_with?(".internal")

    IPAddr.new(host) && LinkResolver.blocked_ip?(host)
  rescue IPAddr::InvalidAddressError
    false
  end

  def initialize(base_url)
    @base = URI(base_url)
    raise ArgumentError, "STEEL_URL must point to the private network" unless self.class.private_host?(@base.host)
  end

  def create_session
    body = JSON.parse(awake { request(Net::HTTP::Post.new("/v1/sessions"), { timeout: 10.minutes.in_milliseconds }) }.body)
    Session.new(body.fetch("id"), body["websocketUrl"], URI(body.fetch("debugUrl")).request_uri.delete_prefix("/"))
  end

  def ws_root = "ws://#{@base.host}:#{@base.port}/"

  def cdp(ws_url)
    # Chrome refuses a DevTools websocket whose Host header is a name, so Ferrum dials a loopback port piped to Steel.
    server = TCPServer.new("127.0.0.1", 0)
    Thread.new do
      loop do
        client = server.accept
        SteelTunnel.pipe(client, open_socket, ttl: nil)
      rescue RemoteBrowser::BrowserFailed
        client.close
      end
    rescue IOError
      nil
    end
    yield URI(ws_url).tap { it.scheme = "ws"; it.host = "127.0.0.1"; it.port = server.addr[1] }.to_s
  ensure
    server&.close
  end

  def open_socket
    TCPSocket.new(@base.host, @base.port, connect_timeout: TIMEOUT)
  rescue SocketError, SystemCallError, IOError => e
    raise RemoteBrowser::BrowserFailed, e.class.name
  end

  def release(id) = request(Net::HTTP::Post.new("/v1/sessions/#{CGI.escape(id)}/release"), {})

  def view(_id, path, query)
    target = [ "/#{path}", query.presence ].compact.join("?")
    res = request(Net::HTTP::Get.new(target))
    [ res.code.to_i, res["content-type"], res.body ]
  end

  private

  def awake(deadline = WAKE.seconds.from_now)
    res = yield
    raise RemoteBrowser::BrowserFailed, "HTTP #{res.code}" unless res.is_a?(Net::HTTPSuccess)

    res
  rescue RemoteBrowser::BrowserFailed
    raise if Time.current > deadline

    sleep 2
    retry
  end

  def request(req, json = nil)
    req.body = json.to_json if json
    req["Content-Type"] = "application/json" if json
    Net::HTTP.start(@base.host, @base.port, use_ssl: @base.scheme == "https",
      open_timeout: TIMEOUT, read_timeout: TIMEOUT) { it.request(req) }
  rescue SystemCallError, IOError, Timeout::Error, Net::ProtocolError => e
    raise RemoteBrowser::BrowserFailed, e.class.name
  end
end
