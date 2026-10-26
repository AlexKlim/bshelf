class LitresCollector
  LOGIN = "https://www.litres.ru/auth/login/".freeze
  TIMEOUT = 60

  API = "https://api.litres.ru".freeze
  PAGE_GAP = 0.4

  # Session-Id and supersid come from cookies the page cannot read itself, so Ruby passes them in.
  PAGE_JS = <<~JS.freeze
    (async (url, headers) => {
      const r = await fetch(url, { headers, credentials: "include" })
      if (!r.ok || !r.headers.get("Powered-By-Litres")) return { status: r.status }
      const payload = (await r.json()).payload || {}
      return { status: 200, arts: payload.data || [], next: payload.pagination?.next_page || null }
    })(URL, HEADERS).then(arguments[0])
  JS

  def steps = %w[library]

  def start(session) = browse(session) { it.go_to(LOGIN) }

  def logged_in?(session)
    browse(session) do |page|
      next false if URI(page.current_url).path.start_with?("/auth/")

      fetch_page(page, library_url(1))["status"] == 200
    end
  end

  def collect(session)
    browse(session) do |page|
      arts = library(page) { yield nil }
      log_shape(arts)
      yield "library"
      LitresImport.call(session.user, arts)
    end
  end

  private

  def library(page)
    arts = []
    url = library_url(24)
    while url
      result = fetch_page(page, url)
      raise RemoteBrowser::ProviderRefused if result["status"] != 200 && arts.empty?
      break if result["status"] != 200

      arts.concat(result["arts"])
      url = next_url(result["next"])
      yield
      sleep PAGE_GAP
    end
    arts
  end

  def library_url(limit) = "#{API}/foundation/api/users/me/arts?limit=#{limit}"

  # The cursor carries + and =, so the reported address is used as is, only its /api/ prefix is wrong.
  def next_url(path)
    return if path.blank?

    url = path.start_with?("http") ? path : API + path
    url.sub(%r{\A#{API}/api/}, "#{API}/foundation/api/")
  end

  def fetch_page(page, url)
    cookies = page.cookies.all
    headers = { "Session-Id" => cookies["SID"]&.value, "supersid" => cookies["supersid"]&.value }.compact
    page.evaluate_async(PAGE_JS.sub("URL") { url.to_json }.sub("HEADERS") { headers.to_json }, TIMEOUT)
  end

  # ponytail: field names beyond id/title/art_type are unconfirmed, drop this once a real library has been read.
  def log_shape(arts)
    Rails.logger.info("[litres] #{arts.size} arts, keys: #{arts.first&.keys&.sort&.join(",")}")
  end

  def browse(session)
    browser = Ferrum::Browser.new(ws_url: session.websocket_url, timeout: TIMEOUT)
    yield browser.page
  rescue Ferrum::Error => e
    raise RemoteBrowser::BrowserFailed, e.class.name
  ensure
    browser&.quit
  end
end
