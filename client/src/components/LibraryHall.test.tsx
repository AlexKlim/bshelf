import { render, screen } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import i18n from "@/i18n"
import type { Shelf } from "@/lib/types"
import { book } from "@/test/fixtures"
import { LibraryHall } from "./LibraryHall"

const years = Array.from({ length: 9 }, (_, i) => String(2025 - i))
const shelves: Shelf[] = [
  { key: "now", count: 1, books: [book({ id: "n1", title: "Now One" })] },
  { key: "want", count: 0, books: [] },
  { key: "2026", count: 1, books: [book({ id: "c1", title: "Current" })] },
  ...years.map((key) => ({ key: key as Shelf["key"], count: 1, books: [book({ id: `y${key}`, title: `Year ${key}` })] })),
]

function prefer(reduced: boolean) {
  window.matchMedia = ((query: string) => ({
    matches: reduced && query.includes("reduced-motion"),
    media: query,
    addEventListener: () => {},
    removeEventListener: () => {},
  })) as unknown as typeof window.matchMedia
}

const hall = (onOpen = vi.fn()) =>
  render(<LibraryHall shelves={shelves} onOpen={onOpen} onTidied={() => {}} onAdd={() => {}} onList={() => {}} onFind={() => {}} />)

describe("LibraryHall", () => {
  beforeEach(async () => {
    prefer(true)
    await i18n.changeLanguage("en")
  })

  it("puts now and want with the current year up front and pages through older years", async () => {
    hall()
    expect(screen.getByRole("button", { name: "Now, Want" })).toBeInTheDocument()
    expect(screen.getByRole("button", { name: "2026, books: 1" })).toBeInTheDocument()
    expect(screen.queryByRole("button", { name: "2020, books: 1" })).not.toBeInTheDocument()

    await userEvent.click(screen.getByRole("button", { name: /Earlier/ }))
    expect(screen.getByRole("button", { name: "2020, books: 1" })).toBeInTheDocument()
    expect(screen.queryByRole("button", { name: "2026, books: 1" })).not.toBeInTheDocument()
  })

  it("opens a case as the bookcase, where a spine still opens its book", async () => {
    const onOpen = vi.fn()
    hall(onOpen)
    await userEvent.click(screen.getByRole("button", { name: "2026, books: 1" }))

    expect(screen.getByRole("region", { name: "2026 · 1" })).toBeInTheDocument()
    await userEvent.click(screen.getByRole("button", { name: /^Current,/ }))
    expect(onOpen).toHaveBeenCalledWith(expect.objectContaining({ id: "c1" }))

    await userEvent.click(screen.getByRole("button", { name: /2025/ }))
    expect(screen.getByRole("region", { name: "2025 · 1" })).toBeInTheDocument()

    await userEvent.click(screen.getByRole("button", { name: "Back to the hall" }))
    expect(screen.getByRole("button", { name: "Now, Want" })).toBeInTheDocument()
  })

  it("puts the case back on Escape or a click beside it", async () => {
    const { container } = hall()
    await userEvent.click(screen.getByRole("button", { name: "2026, books: 1" }))
    await userEvent.keyboard("{Escape}")
    expect(screen.queryByRole("region", { name: "2026 · 1" })).not.toBeInTheDocument()

    await userEvent.click(screen.getByRole("button", { name: "2026, books: 1" }))
    await userEvent.click(container.querySelector(".bs-hall__stage")!)
    expect(screen.queryByRole("region", { name: "2026 · 1" })).not.toBeInTheDocument()
  })

  it("jumps to the page of the year picked in the filter", async () => {
    hall()
    await userEvent.selectOptions(screen.getByRole("combobox", { name: "Year" }), "2017")
    expect(screen.getByRole("button", { name: "2017, books: 1" })).toBeInTheDocument()
  })
})
