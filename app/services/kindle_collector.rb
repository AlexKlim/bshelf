class KindleCollector
  LIBRARY = "https://read.amazon.com/kindle-library".freeze
  TIMEOUT = 60

  LIBRARY_JS = <<~JS.freeze
    (async () => {
      const items = []
      let token = ""
      do {
        const r = await fetch(`/kindle-library/search?query=&libraryType=BOOKS&sortType=acquisition_desc&querySize=50&paginationToken=${token}`)
        if (!r.ok) throw new Error(`library ${r.status}`)
        const page = await r.json()
        items.push(...(page.itemsList || []))
        token = page.paginationToken || ""
      } while (token)
      return items
    })().then(arguments[0])
  JS

  NOTEBOOK_JS = <<~JS.freeze
    (async (asin) => {
      const parse = (html) => new DOMParser().parseFromString(html, "text/html")
      if (!asin) {
        const doc = parse(await (await fetch("/notebook")).text())
        return [...doc.querySelectorAll(".kp-notebook-library-each-book")].map((el) => el.id)
      }
      const notes = []
      let token = "", state = ""
      do {
        const doc = parse(await (await fetch(`/notebook?asin=${asin}&token=${token}&contentLimitState=${state}`)).text())
        doc.querySelectorAll("#kp-notebook-annotations > .a-row").forEach((row) => {
          const text = row.querySelector("#highlight")?.textContent.trim()
          if (text) notes.push({ text, note: row.querySelector("#note")?.textContent.trim() || null,
            location: row.querySelector("#kp-annotation-location")?.value || null })
        })
        token = doc.querySelector(".kp-notebook-annotations-next-page-start")?.value || ""
        state = doc.querySelector(".kp-notebook-content-limit-state")?.value || ""
      } while (token)
      return notes
    })(ASIN).then(arguments[0])
  JS

  def steps = %w[library highlights]

  def start(session) = browse(session) { it.go_to(LIBRARY) }

  def logged_in?(session) = browse(session) { it.current_url.start_with?(LIBRARY) }

  def collect(session)
    browse(session) do |page|
      books = page.evaluate_async(LIBRARY_JS, TIMEOUT)
      yield "library"
      highlights = page.evaluate_async(NOTEBOOK_JS.sub("ASIN", "null"), TIMEOUT).index_with do |asin|
        yield nil
        page.evaluate_async(NOTEBOOK_JS.sub("ASIN", asin.to_json), TIMEOUT)
      end
      yield "highlights"
      KindleImport.call(session.user, books, highlights)
    end
  end

  private

  def browse(session)
    browser = Ferrum::Browser.new(ws_url: session.websocket_url, timeout: TIMEOUT)
    yield browser.page
  rescue Ferrum::Error => e
    raise RemoteBrowser::BrowserFailed, e.class.name
  ensure
    browser&.quit
  end
end
