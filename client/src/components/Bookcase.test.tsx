import { render, screen } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import i18n from "@/i18n"
import type { Shelf } from "@/lib/types"
import { book } from "@/test/fixtures"
import { Bookcase } from "./Bookcase"

const shelves: Shelf[] = [
  { key: "now", count: 2, books: [book({ id: "n1", title: "Now One" }), book({ id: "n2", title: "Now Two" })] },
  { key: "want", count: 0, books: [] },
  {
    key: "2024",
    count: 3,
    books: [book({ id: "y1", title: "Year One" }), book({ id: "y2", title: "Year Two" }), book({ id: "y3", title: "Year Three" })],
  },
]

const spine = (title: string) =>
  screen.getAllByRole("button", { name: new RegExp(`^${title},`) }).find((b) => b.classList.contains("bs-spine"))!

function setPointer(coarse: boolean) {
  window.matchMedia = ((query: string) => ({
    matches: coarse && query.includes("coarse"),
    media: query,
    addEventListener: () => {},
    removeEventListener: () => {},
  })) as unknown as typeof window.matchMedia
}

describe("Bookcase keyboard", () => {
  beforeEach(async () => {
    setPointer(false)
    await i18n.changeLanguage("en")
  })

  it("renders each shelf as a section with a heading and a list", () => {
    render(<Bookcase shelves={shelves} onOpen={() => {}} />)
    expect(screen.getByRole("region", { name: "Now · 2" })).toBeInTheDocument()
    expect(screen.getByRole("heading", { name: "2024 · 3" })).toBeInTheDocument()
    expect(screen.getByText("Nothing here yet")).toBeInTheDocument()
  })

  it("keeps a single spine in the tab order", () => {
    render(<Bookcase shelves={shelves} onOpen={() => {}} />)
    expect(spine("Now One")).toHaveAttribute("tabindex", "0")
    expect(spine("Year One")).toHaveAttribute("tabindex", "-1")
  })

  it("moves along a shelf with left and right and pulls the focused book", async () => {
    render(<Bookcase shelves={shelves} onOpen={() => {}} />)
    await userEvent.tab()
    expect(spine("Now One")).toHaveFocus()

    await userEvent.keyboard("{ArrowRight}")
    expect(spine("Now Two")).toHaveFocus()
    expect(spine("Now Two")).toHaveClass("is-pulled")

    await userEvent.keyboard("{ArrowRight}")
    expect(spine("Now Two")).toHaveFocus()

    await userEvent.keyboard("{ArrowLeft}")
    expect(spine("Now One")).toHaveFocus()
  })

  it("moves between shelves with up and down, skipping empty shelves and keeping the position", async () => {
    render(<Bookcase shelves={shelves} onOpen={() => {}} />)
    await userEvent.tab()
    await userEvent.keyboard("{ArrowRight}{ArrowDown}")
    expect(spine("Year Two")).toHaveFocus()

    await userEvent.keyboard("{End}{ArrowUp}")
    expect(spine("Now Two")).toHaveFocus()

    await userEvent.keyboard("{ArrowUp}")
    expect(spine("Now Two")).toHaveFocus()
  })

  it("opens the focused book with Enter", async () => {
    const onOpen = vi.fn()
    render(<Bookcase shelves={shelves} onOpen={onOpen} />)
    await userEvent.tab()
    await userEvent.keyboard("{ArrowDown}{Enter}")
    expect(onOpen).toHaveBeenCalledWith(expect.objectContaining({ id: "y1" }))
  })

  it("opens on click with a mouse", async () => {
    const onOpen = vi.fn()
    render(<Bookcase shelves={shelves} onOpen={onOpen} />)
    await userEvent.click(spine("Year Three"))
    expect(onOpen).toHaveBeenCalledWith(expect.objectContaining({ id: "y3" }))
  })

  it("on touch, the first tap pulls the book and shows the caption, the second opens it", async () => {
    setPointer(true)
    const onOpen = vi.fn()
    render(<Bookcase shelves={shelves} onOpen={onOpen} />)

    await userEvent.click(spine("Year One"))
    expect(onOpen).not.toHaveBeenCalled()
    expect(spine("Year One")).toHaveAttribute("aria-expanded", "true")
    const caption = screen.getAllByRole("button", { name: "Year One, Author. Listened, Mar 2024" }).find((b) => b.classList.contains("bs-caption"))!

    await userEvent.click(caption)
    expect(onOpen).toHaveBeenCalledWith(expect.objectContaining({ id: "y1" }))
  })

  it("sets the spine text direction from the book language", () => {
    render(<Bookcase shelves={[{ key: "now", count: 1, books: [book({ title: "Дюна", language: null })] }]} onOpen={() => {}} />)
    expect(spine("Дюна")).toHaveAttribute("lang", "ru")
  })
})
