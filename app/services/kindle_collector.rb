class KindleCollector
  LIBRARY = "https://read.amazon.com/kindle-library".freeze
  CONTENT_PAGE = "https://www.amazon.com/hz/mycd/digital-console/contentlist/booksAll/dateDsc/".freeze
  # ponytail: Audible/audible is a guess, Ebook and KindlePDoc are confirmed. Check the log line after a real sync.
  CONTENT = { "Ebook" => "booksAll", "KindlePDoc" => "pdocs", "Audible" => "audible" }.freeze
  CONTENT_BATCH = 50
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

  # One page of "Manage your content and devices": books with Kindle's own READ mark, documents, audiobooks.
  CONTENT_JS = <<~'JS'.freeze
    (async (contentType, contentCategoryReference, startIndex, batchSize) => {
      const csrfToken = (document.documentElement.innerHTML.match(/csrfToken\s*=\s*["']([^"']+)["']/) || [])[1]
      if (!csrfToken) return { error: "no csrf token" }
      const activityInput = JSON.stringify({ contentType, contentCategoryReference, itemStatusList: ["Active"],
        showSharedContent: true, surfaceType: "LargeDesktop",
        fetchCriteria: { sortOrder: "DESCENDING", sortIndex: "DATE", startIndex, batchSize, totalContentCount: -1 } })
      const body = new URLSearchParams({ activity: "GetContentOwnershipData", activityInput, csrfToken })
      const r = await fetch("/hz/mycd/digital-console/ajax", { method: "POST", body })
      if (!r.ok) return { error: `HTTP ${r.status}` }
      const data = (await r.json()).GetContentOwnershipData || {}
      return { items: data.items || [], total: data.numberOfItems || 0 }
    })(ARGS).then(arguments[0])
  JS

  def steps = %w[library highlights]

  def start(session) = RemoteBrowser.open(session, LIBRARY, timeout: TIMEOUT)

  def logged_in?(session) = browse(session) { it.current_url.start_with?(LIBRARY) }

  def collect(session)
    browse(session) do |page|
      books = page.evaluate_async(LIBRARY_JS, TIMEOUT)
      yield "library"
      highlights = page.evaluate_async(NOTEBOOK_JS.sub("ASIN", "null"), TIMEOUT).index_with do |asin|
        yield nil
        page.evaluate_async(NOTEBOOK_JS.sub("ASIN", asin.to_json), TIMEOUT)
      end
      owned = content(page) { yield nil }
      yield "highlights"
      KindleImport.call(session.user, books, highlights, owned)
    end
  end

  private

  def content(page)
    page.go_to(CONTENT_PAGE)
    owned = CONTENT.to_h { |kind, category| [ kind, content_pages(page, kind, category) { yield } ] }
    Rails.logger.info("[kindle] content #{owned.transform_values(&:size)}")
    owned
  end

  def content_pages(page, kind, category)
    items = []
    loop do
      args = [ kind, category, items.size, CONTENT_BATCH ].map(&:to_json).join(", ")
      result = page.evaluate_async(CONTENT_JS.sub("ARGS") { args }, TIMEOUT)
      if result["error"]
        # Best effort: the reader library already came in, so a content page that fails costs only its extras.
        Rails.logger.warn("[kindle] content #{kind} failed: #{result["error"]}")
        break
      end

      items.concat(result["items"])
      yield
      break if result["items"].size < CONTENT_BATCH || items.size >= result["total"]
    end
    items
  end

  def browse(session, &) = RemoteBrowser.browse(session, timeout: TIMEOUT, &)
end
