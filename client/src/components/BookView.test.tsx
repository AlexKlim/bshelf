import { fireEvent, render, screen, waitFor } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import i18n from "@/i18n"
import type { BookDetail } from "@/lib/types"
import { book, mockFetch } from "@/test/fixtures"
import { BookSpread } from "./BookView"

const highlight = (id: string) => ({ id, text: `Quote ${id}`, note: null, location: null, source: "kindle", highlighted_at: null })

const detail = (overrides: Partial<BookDetail> = {}): BookDetail => ({
  ...book({ id: "b1", title: "Solaris" }),
  isbn: null,
  match_source: "manual",
  notes: [],
  highlights: [highlight("h1")],
  highlights_count: 2,
  ...overrides,
})

describe("BookSpread", () => {
  beforeEach(() => i18n.changeLanguage("en"))
  afterEach(() => vi.unstubAllGlobals())

  it("turns More highlights into a retry when the page fails to load", async () => {
    let fail = true
    mockFetch(() => (fail ? [500, {}] : [200, { highlights: [highlight("h2")], count: 2 }]))
    render(<BookSpread book={detail()} onBook={() => {}} onReload={() => {}} />)

    await userEvent.click(screen.getByRole("button", { name: "1 more highlight" }))
    expect(await screen.findByText("Could not load more highlights.")).toBeInTheDocument()

    fail = false
    await userEvent.click(screen.getByRole("button", { name: "Try again" }))
    expect(await screen.findByText("Quote h2")).toBeInTheDocument()
    expect(screen.queryByText("Could not load more highlights.")).toBeNull()
  })

  it("reloads the book when the merge to undo is already gone", async () => {
    mockFetch(() => [404, { errors: [{ code: "not_found" }] }])
    const onReload = vi.fn()
    const merged = detail({ merges: [{ id: "m1", title: "Solaris (EN)", author: null, created_at: "2026-01-01T00:00:00Z" }] })
    render(<BookSpread book={merged} onBook={() => {}} onReload={onReload} />)

    await userEvent.click(screen.getByRole("button", { name: "Unmerge editions" }))
    await vi.waitFor(() => expect(onReload).toHaveBeenCalled())
    expect(screen.queryByText("Not found.")).toBeNull()
  })
})

describe("editing an edition", () => {
  beforeEach(() => i18n.changeLanguage("en"))
  afterEach(() => vi.unstubAllGlobals())

  it("sets the month a book was finished from the edition line", async () => {
    const bodies: unknown[] = []
    mockFetch((url, init) => {
      if (init.method === "PATCH") bodies.push(JSON.parse(String(init.body)))
      return [200, { book: book() }]
    })
    const onReload = vi.fn()
    render(<BookSpread book={detail()} onBook={() => {}} onReload={onReload} />)

    await userEvent.click(screen.getByRole("button", { expanded: false, name: /Audio/ }))
    const when = screen.getByLabelText("When")
    fireEvent.change(when, { target: { value: "2025-03" } })
    fireEvent.blur(when)

    await waitFor(() => expect(onReload).toHaveBeenCalled())
    expect(bodies.at(-1)).toEqual({ status: "done", finished_at: "2025-03-01" })
  })
})
