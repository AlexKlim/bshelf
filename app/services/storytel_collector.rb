class StorytelCollector
  LOGIN = "https://www.storytel.com/login".freeze
  HOME = "https://www.storytel.com/".freeze
  TIMEOUT = 60

  # www.storytel.com keeps its Firebase sign-in in IndexedDB, and that ID token is the bearer api.storytel.net
  # takes. The database is only listed, never opened blind, so a page without it is not left with an empty one.
  # An empty body asks the bookshelf for everything, a JSON one is refused.
  PAGE_JS = <<~JS.freeze
    (async () => {
      const token = (await indexedDB.databases().catch(() => [])).some((d) => d.name === "firebaseLocalStorageDb") && await new Promise((resolve) => {
        setTimeout(() => resolve(null), 5000)
        const open = indexedDB.open("firebaseLocalStorageDb")
        open.onerror = open.onblocked = () => resolve(null)
        open.onsuccess = () => {
          const db = open.result
          if (!db.objectStoreNames.contains("firebaseLocalStorage")) return resolve(null)
          const all = db.transaction("firebaseLocalStorage").objectStore("firebaseLocalStorage").getAll()
          all.onerror = () => resolve(null)
          all.onsuccess = () => resolve(all.result.find((e) => String(e.fbase_key).startsWith("firebase:authUser:"))?.value?.stsTokenManager?.accessToken || null)
        }
      })
      if (!token) return { status: 401 }
      const r = await fetch("https://api.storytel.net/libraries/bookshelf", {
        method: "POST", body: "", headers: { Authorization: `Bearer ${token}`, "content-type": "application/x-www-form-urlencoded" },
      }).catch(() => null)
      if (!r?.ok) return { status: r?.status || 0 }
      const body = await r.json().catch(() => null)
      if (!body?.items || typeof body.items !== "object") return { status: 0 }
      return { status: 200, items: Object.values(body.items) }
    })().then(arguments[0])
  JS

  def steps = %w[library]

  def start(session) = RemoteBrowser.open(session, LOGIN, timeout: TIMEOUT)

  def logged_in?(session)
    browse(session) do |page|
      url = URI(page.current_url)
      next false unless storytel?(url.host) && !url.path.include?("login") && page.cookies["storytel_session"]

      # Some markets land on private.storytel.com after sign in, but the token lives on www.
      page.go_to(HOME) unless url.host == URI(HOME).host
      result = bookshelf(page)
      Rails.logger.info("[storytel] signed in, bookshelf answered #{result["status"]}") unless result["status"] == 200
      result["status"] == 200
    end
  end

  def collect(session)
    browse(session) do |page|
      raise RemoteBrowser::PageChanged unless storytel?(URI(page.current_url).host)

      result = bookshelf(page)
      raise RemoteBrowser::ProviderRefused unless result["status"] == 200

      log_shape(result["items"])
      yield "library"
      StorytelImport.call(session.user, result["items"])
    end
  end

  private

  def storytel?(host) = host.to_s.delete_prefix(".").then { it == "storytel.com" || it.end_with?(".storytel.com") }

  def bookshelf(page) = page.evaluate_async(PAGE_JS, TIMEOUT)

  # ponytail: the shape comes from an unofficial client, drop this once a real bookshelf has been read.
  def log_shape(items)
    states = Array(items).map { it.dig("model", "state") }.tally
    Rails.logger.info("[storytel] #{Array(items).size} items, states: #{states}, keys: #{Array(items).first&.dig("model")&.keys&.sort&.join(",")}")
  end

  def browse(session, &) = RemoteBrowser.browse(session, timeout: TIMEOUT, &)
end
