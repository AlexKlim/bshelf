class LitresCollector
  LOGIN = "https://www.litres.ru/auth/login/".freeze
  TIMEOUT = 60

  # Session-Id and supersid come from cookies the page cannot read itself, so Ruby passes them in.
  ARTS_JS = <<~JS.freeze
    (async (headers, limit) => {
      const api = "https://api.litres.ru"
      const arts = []
      let url = `${api}/foundation/api/users/me/arts?limit=${limit}`
      while (url) {
        const r = await fetch(url, { headers, credentials: "include" })
        if (!r.ok || !r.headers.get("Powered-By-Litres")) return { status: r.status, arts }
        const payload = (await r.json()).payload || {}
        arts.push(...(payload.data || []))
        if (limit === 1) break
        const next = payload.pagination?.next_page
        url = next ? (next.startsWith("http") ? next : api + next).replace("/api/", "/foundation/api/") : null
        await new Promise((ok) => setTimeout(ok, 400))
      }
      return { status: 200, arts }
    })(HEADERS, LIMIT).then(arguments[0])
  JS

  def steps = %w[library]

  def start(session) = browse(session) { it.go_to(LOGIN) }

  def logged_in?(session)
    browse(session) do |page|
      next false if URI(page.current_url).path.start_with?("/auth/")

      arts(page, limit: 1)["status"] == 200
    end
  end

  def collect(session)
    browse(session) do |page|
      result = arts(page, limit: 24)
      raise RemoteBrowser::ProviderRefused unless result["status"] == 200

      log_shape(result["arts"])
      yield "library"
      LitresImport.call(session.user, result["arts"])
    end
  end

  private

  def arts(page, limit:)
    cookies = page.cookies.all
    headers = { "Session-Id" => cookies["SID"]&.value, "supersid" => cookies["supersid"]&.value }.compact
    page.evaluate_async(ARTS_JS.sub("HEADERS", headers.to_json).sub("LIMIT", limit.to_s), TIMEOUT)
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
