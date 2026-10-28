import { render, screen } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { MemoryRouter } from "react-router-dom"
import i18n from "@/i18n"
import type { Stats, StatsBook } from "@/lib/types"
import { mockFetch } from "@/test/fixtures"
import { StatsScreen } from "./StatsScreen"

const thisYear = new Date().getFullYear()

const row = (id: string, extra: Partial<StatsBook> = {}): StatsBook => ({
  id,
  title: `Book ${id}`,
  author: null,
  formats: ["audio"],
  finished_at: `${thisYear}-03-10T00:00:00.000Z`,
  minutes: null,
  ...extra,
})

function stats(year: number, overrides: Partial<Stats> = {}): Stats {
  return {
    year,
    years: [thisYear, thisYear - 2],
    total: 0,
    by_format: {},
    total_minutes: null,
    months: Array.from({ length: 12 }, (_, i) => ({ month: i + 1, books: [] as StatsBook[] })),
    no_date_count: 0,
    top_authors: [],
    ...overrides,
  }
}

const renderStats = () =>
  render(
    <MemoryRouter>
      <StatsScreen />
    </MemoryRouter>,
  )

describe("StatsScreen", () => {
  beforeEach(() => i18n.changeLanguage("en"))
  afterEach(() => vi.unstubAllGlobals())

  it("offers every year the server returns, next year included", async () => {
    mockFetch((url) => {
      const year = Number(new URL(url, "http://x").searchParams.get("year") ?? thisYear)
      return [200, stats(year, { years: [thisYear + 1, thisYear - 1] })]
    })
    renderStats()

    expect(await screen.findByRole("button", { name: `Next year ${thisYear + 1}` })).toBeInTheDocument()
    expect(screen.getByRole("button", { name: `Previous year ${thisYear - 1}` })).toBeInTheDocument()
  })

  it("offers only years that exist plus the current one", async () => {
    mockFetch((url) => {
      const year = Number(new URL(url, "http://x").searchParams.get("year") ?? thisYear)
      return [200, stats(year)]
    })
    renderStats()

    const prev = await screen.findByRole("button", { name: `Previous year ${thisYear - 2}` })
    expect(screen.queryByRole("button", { name: /^Next year/ })).toBeNull()

    await userEvent.click(prev)

    expect(await screen.findByRole("button", { name: `Next year ${thisYear}` })).toBeInTheDocument()
    expect(screen.queryByRole("button", { name: /^Previous year/ })).toBeNull()
  })

  it("draws the genre star with each genre's share of the year", async () => {
    mockFetch(() => [200, stats(thisYear, { total: 8, by_genre: { psychology: 3, fantasy: 1 } })])
    renderStats()

    const star = await screen.findByRole("img", { name: /^0% Fiction, 13% Sci-fi & fantasy, 0% Crime, 38% Psychology/ })
    expect(star).toBeInTheDocument()
  })

  it("leaves the star out until a genre is known", async () => {
    mockFetch(() => [200, stats(thisYear, { total: 4, by_genre: {} })])
    renderStats()

    await screen.findByRole("button", { name: /^Previous year/ })
    expect(screen.queryByText("Genres")).toBeNull()
  })

  it("labels the year buttons in Russian", async () => {
    await i18n.changeLanguage("ru")
    mockFetch(() => [200, stats(thisYear)])
    renderStats()
    expect(await screen.findByRole("button", { name: `Предыдущий год ${thisYear - 2}` })).toBeInTheDocument()
  })

  it("takes the cloth and the listened and read counts from the server", async () => {
    const months = stats(thisYear).months
    months[2].books = [row("a", { cloth: "plum" }), row("b"), row("c", { formats: ["ebook", "personal_doc"] })]
    mockFetch(() => [200, stats(thisYear, { total: 3, by_format: { audio: 2, ebook: 1, personal_doc: 1 }, listened: 2, read: 1, months })])
    const { container } = renderStats()

    expect(await screen.findByRole("heading", { name: `${thisYear}: 3 books · 2 listened · 1 read` })).toBeInTheDocument()
    const books = container.querySelectorAll(".bs-stack__book")
    expect(books[0]).toHaveClass("bs-cloth--plum")
    expect(books[1]).toHaveClass("bs-cloth--blank")
  })
})
