require "net/http"

# Self-hosted Steel (eng D4). The live view has no auth of its own (OV-1), so Steel must sit on
# the private network and only Rails, after its token check, talks to it.
# ponytail: endpoint shapes follow the steel-browser README; pin them after the ET2 spike.
class SteelClient
  Session = Data.define(:id, :websocket_url, :viewer_path)
  TIMEOUT = 5

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
    body = JSON.parse(request(Net::HTTP::Post.new("/v1/sessions"), { timeout: 10.minutes.in_milliseconds }).body)
    Session.new(body.fetch("id"), body["websocketUrl"], URI(body.fetch("debugUrl")).request_uri.delete_prefix("/"))
  end

  def release(id) = request(Net::HTTP::Post.new("/v1/sessions/#{CGI.escape(id)}/release"), {})

  def view(_id, path, query)
    target = [ "/#{path}", query.presence ].compact.join("?")
    res = request(Net::HTTP::Get.new(target))
    [ res.code.to_i, res["content-type"], res.body ]
  end

  private

  def request(req, json = nil)
    req.body = json.to_json if json
    req["Content-Type"] = "application/json" if json
    Net::HTTP.start(@base.host, @base.port, use_ssl: @base.scheme == "https",
      open_timeout: TIMEOUT, read_timeout: TIMEOUT) { it.request(req) }
  rescue SystemCallError, IOError, Timeout::Error, Net::ProtocolError => e
    raise RemoteBrowser::BrowserFailed, e.class.name
  end
end
