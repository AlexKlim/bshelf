require "ipaddr"
require "net/http"
require "socket"

class LinkResolver
  class Failed < StandardError; end

  Link = Data.define(:store, :external_id)

  STORES = {
    "litres" => %w[litres.ru litres.com],
    "amazon" => %w[
      amazon.com amazon.co.uk amazon.de amazon.fr amazon.it amazon.es amazon.nl amazon.se amazon.pl
      amazon.ca amazon.com.au amazon.com.br amazon.com.mx amazon.co.jp amazon.in
      a.co amzn.to amzn.eu amzn.asia
    ]
  }.freeze
  MAX_REDIRECTS = 3
  BUDGET = 1.5
  REDIRECTS = [ 301, 302, 303, 307, 308 ].freeze
  ASIN = %r{/(?:dp|gp/product|gp/aw/d|exec/obidos/ASIN)/([A-Z0-9]{10})(?:[/?]|\z)}i
  LITRES_ID = %r{[-/](\d{3,})/?\z}
  BLOCKED = %w[0.0.0.0/8 100.64.0.0/10 192.0.0.0/24 198.18.0.0/15 224.0.0.0/4 240.0.0.0/4 ::/128 ff00::/8 64:ff9b::/96]
    .map { IPAddr.new(it) }

  def self.store_for(host)
    host = host.to_s.downcase.delete_suffix(".")
    STORES.find { |_, domains| domains.any? { host == it || host.end_with?(".#{it}") } }&.first
  end

  def self.parse(uri)
    case store_for(uri.host)
    when "litres" then (id = uri.path[LITRES_ID, 1]) && Link.new("litres", id)
    when "amazon" then (asin = uri.path[ASIN, 1]) && Link.new("amazon", asin.upcase)
    end
  end

  def self.blocked_ip?(ip)
    addr = IPAddr.new(ip).native
    addr.private? || addr.loopback? || addr.link_local? || BLOCKED.any? { it.include?(addr) }
  rescue IPAddr::InvalidAddressError
    true
  end

  def self.lookup(host, timeout)
    Addrinfo.getaddrinfo(host, nil, nil, :STREAM, timeout:).map(&:ip_address).uniq
  rescue SocketError, IO::TimeoutError
    []
  end

  def self.http_get(uri, ip, timeout)
    http = Net::HTTP.new(uri.host, uri.port)
    http.ipaddr = ip
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = http.read_timeout = http.write_timeout = http.ssl_timeout = timeout
    http.max_retries = 0
    http.start do
      # Returning before read_body closes the socket: only the status and Location are ever read.
      http.request_get(uri.request_uri, "User-Agent" => "BookShelf/1.0") { return [ it.code.to_i, it["location"] ] }
    end
  end

  def call(url)
    deadline = monotonic + BUDGET
    uri = parse_uri(url)
    (MAX_REDIRECTS + 1).times do
      link = self.class.parse(uri)
      return link if link

      status, location = hop(uri, deadline)
      return unless REDIRECTS.include?(status) && location.present?

      uri = parse_uri(URI.join(uri, location).to_s)
    end
    raise Failed, "too many redirects"
  rescue URI::Error
    raise Failed, "invalid url"
  end

  private

  def parse_uri(url)
    uri = URI.parse(url.to_s.strip)
    raise Failed, "scheme" unless uri.is_a?(URI::HTTP) && uri.host
    raise Failed, "host not allowed" unless self.class.store_for(uri.host)
    raise Failed, "port" unless uri.port == uri.default_port && uri.userinfo.nil?

    uri
  end

  def hop(uri, deadline)
    remaining = deadline - monotonic
    raise Failed, "timeout" if remaining <= 0

    Timeout.timeout(remaining, Failed, "timeout") do
      ips = self.class.lookup(uri.host, remaining)
      raise Failed, "private address" if ips.empty? || ips.any? { self.class.blocked_ip?(it) }

      self.class.http_get(uri, ips.first, remaining)
    end
  rescue SystemCallError, IOError, Timeout::Error, OpenSSL::SSL::SSLError, Net::ProtocolError
    raise Failed, "network"
  end

  def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)
end
