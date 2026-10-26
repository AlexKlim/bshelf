import { render, screen, within } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { MemoryRouter } from "react-router-dom"
import i18n from "@/i18n"
import { mockFetch } from "@/test/fixtures"
import App from "./App"

const user = { id: "u1", email: "reader@example.com", created_at: "2026-10-25T10:00:00.000Z" }

function serve() {
  return mockFetch((url) => {
    if (url.startsWith("/api/v1/shelf")) return [200, { shelves: [] }]
    if (url.startsWith("/api/v1/sources")) return [200, { sources: [], banner: null }]
    if (url.startsWith("/api/v1/stats")) {
      return [200, { year: 2026, years: [], total: 0, by_format: {}, total_minutes: null, months: Array.from({ length: 12 }, (_, i) => ({ month: i + 1, books: [] })), no_date_count: 0, top_authors: [] }]
    }
    if (url.startsWith("/api/v1/me")) return [401, { errors: [{ code: "unauthorized" }] }]
    return [404, { errors: [{ code: "not_found" }] }]
  })
}

describe("App shell", () => {
  beforeEach(() => i18n.changeLanguage("en"))
  afterEach(() => vi.unstubAllGlobals())

  it("renders the three tabs and marks the current one", () => {
    serve()
    render(<MemoryRouter initialEntries={["/stats"]}><App initialUser={user} /></MemoryRouter>)

    const nav = screen.getByRole("navigation", { name: "Sections" })
    expect(within(nav).getAllByRole("link")).toHaveLength(3)
    expect(within(nav).getByRole("link", { name: "Stats" })).toHaveAttribute("aria-current", "page")
    expect(within(nav).getByRole("link", { name: "Bookcase" })).not.toHaveAttribute("aria-current")
    expect(screen.queryByRole("tab")).toBeNull()
  })

  it("navigates between tabs", async () => {
    serve()
    render(<MemoryRouter><App initialUser={user} /></MemoryRouter>)

    await userEvent.click(screen.getByRole("link", { name: "Sources" }))

    expect(await screen.findByRole("heading", { name: "Sources" })).toBeInTheDocument()
  })

  it("shows the empty bookcase with its three paths", async () => {
    serve()
    render(<MemoryRouter><App initialUser={user} /></MemoryRouter>)

    expect(await screen.findByRole("heading", { name: "The bookcase is empty for now" })).toBeInTheDocument()
    expect(screen.getByRole("button", { name: "Sign in to Litres" })).toBeInTheDocument()
    expect(screen.getByRole("button", { name: "Sync Kindle" })).toBeInTheDocument()
    expect(screen.getByRole("button", { name: "Add book" })).toBeInTheDocument()
  })

  it("shows a signed-out visitor at / the landing and a signed-in user the bookcase", async () => {
    serve()
    const { unmount } = render(<MemoryRouter><App /></MemoryRouter>)

    expect(await screen.findByRole("heading", { level: 1, name: "Everything you have read and listened to, on one shelf" })).toBeInTheDocument()
    expect(screen.getAllByRole("link", { name: "Create a shelf" })[0]).toHaveAttribute("href", "/register")
    expect(screen.getByRole("link", { name: "Sign in" })).toHaveAttribute("href", "/login")
    expect(document.title).toBe("Book Shelf: everything you have read and listened to, on one shelf")
    unmount()

    render(<MemoryRouter><App initialUser={user} /></MemoryRouter>)

    expect(await screen.findByRole("heading", { name: "The bookcase is empty for now" })).toBeInTheDocument()
    expect(screen.queryByRole("heading", { level: 1, name: "Everything you have read and listened to, on one shelf" })).toBeNull()
  })

  it("sends a signed-out visitor to the sign in from other screens", async () => {
    serve()
    render(<MemoryRouter initialEntries={["/stats"]}><App /></MemoryRouter>)

    expect(await screen.findByRole("heading", { name: "Sign in" })).toBeInTheDocument()
  })

  it("marks the language chips with their own language", async () => {
    serve()
    render(<MemoryRouter initialEntries={["/account/language"]}><App initialUser={user} /></MemoryRouter>)

    expect((await screen.findByRole("radio", { name: "Русский" })).closest("label")).toHaveAttribute("lang", "ru")
    expect(screen.getByRole("radio", { name: "English" }).closest("label")).toHaveAttribute("lang", "en")
  })

  it("switches to Russian", async () => {
    serve()
    await i18n.changeLanguage("ru")
    render(<MemoryRouter><App initialUser={user} /></MemoryRouter>)

    expect(screen.getByRole("link", { name: "Шкаф" })).toBeInTheDocument()
  })
})
