import { act, render, screen, waitFor } from "@testing-library/react"
import { book, mockFetch } from "@/test/fixtures"
import { readCache, writeCache } from "./cache"
import { ShelfProvider, useShelf } from "./shelf"

const first = Array.from({ length: 40 }, (_, i) => book({ id: `a${i}` }))
const second = Array.from({ length: 5 }, (_, i) => book({ id: `b${i}` }))

function Probe() {
  const { shelves, loadMore } = useShelf()
  return (
    <>
      <p>{shelves ? shelves.map((s) => `${s.key}:${s.books.length}/${s.count}`).join(" ") : "loading"}</p>
      <button onClick={() => loadMore("2024")}>more</button>
    </>
  )
}

describe("ShelfProvider", () => {
  afterEach(() => {
    vi.unstubAllGlobals()
    localStorage.clear()
  })

  it("asks for 40 books per shelf and pages one shelf through /shelf/:key", async () => {
    const fetch = mockFetch((url) => {
      if (url === "/api/v1/shelf?limit=40") return [200, { shelves: [{ key: "2024", count: 45, books: first }] }]
      if (url === "/api/v1/shelf/2024?offset=40&limit=40") return [200, { key: "2024", count: 45, books: second }]
      return [404, {}]
    })
    render(
      <ShelfProvider>
        <Probe />
      </ShelfProvider>,
    )
    expect(await screen.findByText("2024:40/45")).toBeInTheDocument()

    await act(async () => screen.getByText("more").click())

    expect(await screen.findByText("2024:45/45")).toBeInTheDocument()
    expect(fetch).toHaveBeenCalledTimes(2)
    expect(readCache<{ books: unknown[] }[]>("shelf")?.[0].books).toHaveLength(40)
  })

  it("does not ask again once a shelf is complete", async () => {
    const fetch = mockFetch(() => [200, { shelves: [{ key: "2024", count: 2, books: second.slice(0, 2) }] }])
    render(
      <ShelfProvider>
        <Probe />
      </ShelfProvider>,
    )
    await screen.findByText("2024:2/2")
    await act(async () => screen.getByText("more").click())
    await waitFor(() => expect(fetch).toHaveBeenCalledTimes(1))
  })
})

describe("writeCache", () => {
  afterEach(() => localStorage.clear())

  it("drops a value too large for localStorage instead of keeping a stale one", () => {
    writeCache("shelf", ["small"])
    writeCache("shelf", ["x".repeat(2_000_000)])
    expect(readCache("shelf")).toBeNull()
  })
})
