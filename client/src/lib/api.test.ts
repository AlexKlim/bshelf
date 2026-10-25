import { api, ApiError } from "./api"

function mockFetch(status: number, body: unknown) {
  const fn = vi.fn().mockResolvedValue(new Response(status === 204 ? null : JSON.stringify(body), { status }))
  vi.stubGlobal("fetch", fn)
  return fn
}

describe("api", () => {
  afterEach(() => {
    vi.unstubAllGlobals()
    document.cookie = "CSRF-TOKEN=; expires=Thu, 01 Jan 1970 00:00:00 GMT"
  })

  it("sends the CSRF token from the cookie on writes", async () => {
    document.cookie = "CSRF-TOKEN=abc%2B1"
    const fetch = mockFetch(201, { ok: true })

    await api("/books", { method: "POST", body: { title: "X" } })

    const [url, init] = fetch.mock.calls[0]
    expect(url).toBe("/api/v1/books")
    expect(init.headers["X-CSRF-Token"]).toBe("abc+1")
    expect(init.body).toBe(JSON.stringify({ title: "X" }))
  })

  it("throws ApiError with the error code", async () => {
    mockFetch(409, { errors: [{ code: "duplicate", field: "title" }], existing: { id: "u1" } })

    const error = (await api("/books", { method: "POST", body: {} }).catch((e) => e)) as ApiError

    expect(error).toBeInstanceOf(ApiError)
    expect(error.code).toBe("duplicate")
    expect(error.status).toBe(409)
    expect(error.body.existing).toEqual({ id: "u1" })
  })

  it("returns undefined for 204", async () => {
    mockFetch(204, null)
    await expect(api("/session", { method: "DELETE" })).resolves.toBeUndefined()
  })
})
