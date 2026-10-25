import { readFileSync } from "node:fs"
import { resolve } from "node:path"

type Listener = (event: Record<string, unknown>) => void

function loadWorker() {
  const listeners: Record<string, Listener> = {}
  const store = new Map<string, Response>()
  const deleted: string[] = []
  const cache = {
    add: vi.fn(async () => {}),
    put: vi.fn(async (key: Request | string, response: Response) => {
      store.set(typeof key === "string" ? key : new URL(key.url).pathname, response)
    }),
  }
  const caches = {
    open: vi.fn(async () => cache),
    keys: vi.fn(async () => ["bshelf-shell-old", "bshelf-shell-__BUILD__"]),
    delete: vi.fn(async (key: string) => deleted.push(key)),
    match: vi.fn(async () => undefined),
  }
  const self = {
    location: { origin: "https://shelf.test" },
    addEventListener: (type: string, fn: Listener) => (listeners[type] = fn),
    skipWaiting: () => {},
    clients: { claim: () => {} },
  }
  const network = vi.fn<(request: Request) => Promise<Response>>()
  const source = readFileSync(resolve(__dirname, "../public/sw.js"), "utf8")
  new Function("self", "caches", "fetch", source)(self, caches, network)

  async function request(path: string, response: Response, mode: RequestMode = "navigate") {
    network.mockResolvedValueOnce(response)
    let responded: Promise<Response> | undefined
    const req = { url: `https://shelf.test${path}`, method: "GET", mode } as Request
    listeners.fetch({ request: req, respondWith: (p: Promise<Response>) => (responded = p) })
    if (responded) await responded
    await new Promise((r) => setTimeout(r))
    return { intercepted: !!responded }
  }

  return { listeners, store, deleted, cache, request }
}

const html = (headers: Record<string, string> = {}) =>
  new Response("<!doctype html>", { status: 200, headers: { "Content-Type": "text/html; charset=utf-8", ...headers } })

describe("service worker", () => {
  it("stores an SPA navigation as the shell", async () => {
    const sw = loadWorker()
    await sw.request("/stats", html())
    expect(sw.store.has("/")).toBe(true)
  })

  it("never intercepts OAuth, discovery, MCP, health and API paths", async () => {
    const sw = loadWorker()
    for (const path of ["/oauth/authorize?x=1", "/.well-known/oauth-authorization-server", "/mcp", "/up", "/api/v1/shelf"]) {
      const { intercepted } = await sw.request(path, html())
      expect(intercepted, path).toBe(false)
    }
    expect(sw.store.size).toBe(0)
  })

  it("does not take a non-HTML navigation as the shell", async () => {
    const sw = loadWorker()
    await sw.request("/share", new Response("{}", { status: 200, headers: { "Content-Type": "application/json" } }))
    expect(sw.store.size).toBe(0)
  })

  it("respects Cache-Control no-store", async () => {
    const sw = loadWorker()
    await sw.request("/", html({ "Cache-Control": "no-store" }))
    await sw.request("/assets/app.js", new Response("x", { headers: { "Cache-Control": "private, no-store" } }), "no-cors")
    expect(sw.store.size).toBe(0)
  })

  it("names the cache per build and deletes the old ones on activate", async () => {
    const sw = loadWorker()
    let done: Promise<unknown> = Promise.resolve()
    sw.listeners.activate({ waitUntil: (p: Promise<unknown>) => (done = p) })
    await done
    expect(sw.deleted).toEqual(["bshelf-shell-old"])
  })
})
