import { render, screen, waitFor } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { MemoryRouter } from "react-router-dom"
import App from "@/App"
import i18n from "@/i18n"
import { book, mockFetch } from "@/test/fixtures"

const user = { id: "u1", email: "reader@example.com", created_at: "2026-10-25T10:00:00.000Z" }

describe("BookcaseScreen", () => {
  beforeEach(() => i18n.changeLanguage("en"))
  afterEach(() => {
    vi.unstubAllGlobals()
    localStorage.clear()
  })

  it("keeps one banner when the shelf cannot load offline: offline in the slot, a plain retry row below", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => {
        throw new TypeError("Failed to fetch")
      }),
    )
    const { container } = render(
      <MemoryRouter>
        <App initialUser={user} />
      </MemoryRouter>,
    )

    expect(await screen.findByText("Could not load the bookcase.")).toBeInTheDocument()
    expect(screen.getByText("No network. The bookcase is shown from cache.")).toBeInTheDocument()
    expect(container.querySelectorAll(".bs-banner")).toHaveLength(1)
    expect(screen.queryByRole("alert")).toBeNull()
    expect(screen.getByRole("button", { name: "Try again" })).toBeInTheDocument()
  })
})

describe("BookcaseScreen opening a book", () => {
  const solaris = book({ id: "sol", title: "Solaris" })
  const dune = book({ id: "dune", title: "Dune" })
  const original = window.matchMedia

  const prefer = (reduced: boolean) => {
    window.matchMedia = ((query: string) => ({
      matches: reduced && query.includes("reduced-motion"),
      media: query,
      addEventListener: () => {},
      removeEventListener: () => {},
    })) as unknown as typeof window.matchMedia
  }

  beforeEach(async () => {
    await i18n.changeLanguage("en")
    prefer(false)
    localStorage.setItem("bs:view", "case")
    mockFetch((url) => {
      if (url.startsWith("/api/v1/shelf")) return [200, { shelves: [{ key: "2024", count: 2, books: [solaris, dune] }] }]
      if (url.startsWith("/api/v1/sources")) return [200, { sources: [], banner: null }]
      if (url === "/api/v1/books/sol") return [200, { book: { ...solaris, isbn: null, match_source: "manual", notes: [], highlights: [], highlights_count: 0 } }]
      return [404, { errors: [{ code: "not_found" }] }]
    })
  })
  afterEach(() => {
    window.matchMedia = original
    vi.unstubAllGlobals()
    localStorage.clear()
  })

  const renderAt = (path = "/") =>
    render(
      <MemoryRouter initialEntries={[path]}>
        <App initialUser={user} />
      </MemoryRouter>,
    )
  const spread = () => screen.queryByRole("heading", { level: 1, name: "Solaris" })
  const spine = (title: string) => document.querySelector<HTMLElement>(`.bs-spine[aria-label^="${title},"]`)!

  it("flies the book out of the clicked spine inside a dialog over the bookcase", async () => {
    renderAt()
    await screen.findByRole("region", { name: "2024 · 2" })
    spine("Solaris").getBoundingClientRect = () => new DOMRect(100, 200, 30, 160)
    await userEvent.click(spine("Solaris"))

    const dialog = await screen.findByRole("dialog", { name: "Solaris" })
    const fly = dialog.querySelector<HTMLElement>(".bs-book.bs-fly")!
    expect(fly.style.getPropertyValue("--from-x")).toBe("115px")
    expect(fly.style.getPropertyValue("--from-y")).toBe("280px")
    expect(dialog.querySelector(".bs-flap")).toHaveTextContent("Solaris")
    expect(screen.getByRole("region", { name: "2024 · 2", hidden: true })).toBeInTheDocument()
  })

  it("just shows the open book when motion is reduced", async () => {
    prefer(true)
    renderAt()
    await screen.findByRole("region", { name: "2024 · 2" })
    await userEvent.click(spine("Solaris"))

    const dialog = await screen.findByRole("dialog", { name: "Solaris" })
    expect(dialog.querySelector(".bs-book")).toBeInTheDocument()
    expect(dialog.querySelector(".bs-fly, .bs-flap")).toBeNull()
  })

  it("moves focus to the spread heading when a book opens and back to its spine when it closes", async () => {
    renderAt()
    await screen.findByRole("region", { name: "2024 · 2" })
    await userEvent.click(spine("Solaris"))

    await waitFor(() => expect(spread()).toHaveFocus())

    await userEvent.keyboard("{Escape}")
    await waitFor(() => expect(spread()).toBeNull())
    expect(spine("Solaris")).toHaveFocus()

    await userEvent.click(spine("Solaris"))
    await waitFor(() => expect(spread()).toHaveFocus())
  })

  it("returns focus to the list row that opened the book", async () => {
    localStorage.setItem("bs:view", "list")
    renderAt()
    await screen.findByRole("region", { name: "2024 · 2" })
    const row = document.querySelector<HTMLElement>('.bs-row[data-book="sol"]')!
    await userEvent.click(row)
    await waitFor(() => expect(spread()).toHaveFocus())

    await userEvent.click(screen.getByRole("button", { name: "Close" }))
    await waitFor(() => expect(spread()).toBeNull())
    expect(row).toHaveFocus()
  })

  it("ignores Esc typed in a field inside the book", async () => {
    renderAt("/?book=sol")
    await userEvent.click(await screen.findByRole("button", { name: "Add note" }))
    await userEvent.keyboard("{Escape}")
    expect(spread()).toBeInTheDocument()
  })
})
