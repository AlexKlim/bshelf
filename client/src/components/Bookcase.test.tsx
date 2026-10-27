import { render, screen } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import i18n from "@/i18n"
import type { Shelf } from "@/lib/types"
import { book } from "@/test/fixtures"
import { Bookcase } from "./Bookcase"
import { ShelfList } from "./ShelfList"

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

  it("throws the focused book away with Delete and moves on to its neighbour", async () => {
    const onDiscard = vi.fn()
    const { rerender } = render(<Bookcase shelves={shelves} onOpen={() => {}} onMove={() => {}} onDiscard={onDiscard} />)
    spine("Year Two").focus()

    await userEvent.keyboard("{Delete}")

    expect(onDiscard).toHaveBeenCalledWith(expect.objectContaining({ id: "y2" }))
    expect(spine("Year Three")).toHaveFocus()
    const left = shelves.map((s) => ({ ...s, books: s.books.filter((b) => b.id !== "y2") }))
    rerender(<Bookcase shelves={left} onOpen={() => {}} onMove={() => {}} onDiscard={onDiscard} />)
    expect(spine("Year Three")).toHaveAttribute("tabindex", "0")
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

describe("search", () => {
  afterEach(() => {
    vi.restoreAllMocks()
    Reflect.deleteProperty(HTMLElement.prototype, "scrollBy")
  })

  it("scrolls each shelf sideways to its first match", () => {
    setPointer(false)
    const scrolled: [string, number][] = []
    HTMLElement.prototype.scrollBy = function (this: HTMLElement, options?: ScrollToOptions | number) {
      scrolled.push([this.closest("section")!.id || this.closest("section")!.getAttribute("aria-labelledby")!, (options as ScrollToOptions).left!])
    } as typeof HTMLElement.prototype.scrollBy
    vi.spyOn(HTMLElement.prototype, "getBoundingClientRect").mockImplementation(function (this: HTMLElement) {
      const far = this.classList.contains("bs-spine") && this.getAttribute("aria-label")!.startsWith("Year Three")
      const left = this.classList.contains("bs-shelf__row") ? 0 : far ? 900 : 10
      const width = this.classList.contains("bs-shelf__row") ? 390 : 32
      return { left, right: left + width, top: 0, bottom: 0, width, height: 0, x: left, y: 0, toJSON: () => ({}) }
    })
    const { rerender } = render(<Bookcase shelves={shelves} onOpen={() => {}} />)
    rerender(<Bookcase shelves={shelves} matches={new Set(["y3", "n1"])} onOpen={() => {}} />)

    expect(scrolled).toHaveLength(1)
    expect(scrolled[0][0]).toBe("shelf-2024")
    expect(scrolled[0][1]).toBeGreaterThan(500)
  })
})

describe("paging", () => {
  afterEach(() => vi.unstubAllGlobals())

  function observe() {
    const seen: { fire: () => void; root: Element | null }[] = []
    vi.stubGlobal(
      "IntersectionObserver",
      class {
        cb: (entries: { isIntersecting: boolean }[]) => void
        root: Element | null
        constructor(cb: (entries: { isIntersecting: boolean }[]) => void, options: { root?: Element | null } = {}) {
          this.cb = cb
          this.root = options.root ?? null
        }
        observe() {
          seen.push({ fire: () => this.cb([{ isIntersecting: true }]), root: this.root })
        }
        disconnect() {}
      },
    )
    return seen
  }

  const partial: Shelf[] = [
    { key: "2024", count: 5, books: [book({ id: "p1" })] },
    { key: "2023", count: 1, books: [book({ id: "p2" })] },
  ]

  it("asks for more books when the end of a partly loaded shelf scrolls into view", () => {
    const seen = observe()
    const onMore = vi.fn()
    render(<Bookcase shelves={partial} onOpen={() => {}} onMore={onMore} />)
    expect(seen).toHaveLength(1)
    expect(seen[0].root).toBeNull()
    seen[0].fire()
    expect(onMore).toHaveBeenCalledWith("2024")
  })

  it("does the same at the end of a shelf in the list view", () => {
    const seen = observe()
    const onMore = vi.fn()
    render(<ShelfList shelves={partial} onOpen={() => {}} onMore={onMore} />)
    expect(seen).toHaveLength(1)
    seen[0].fire()
    expect(onMore).toHaveBeenCalledWith("2024")
  })
})

describe("dragging a book", () => {
  it("moves a book to the shelf it is dropped on without opening it", async () => {
    setPointer(false)
    const user = userEvent.setup()
    const onMove = vi.fn()
    const onOpen = vi.fn()
    render(<Bookcase shelves={shelves} onOpen={onOpen} onMove={onMove} />)
    const target = document.querySelector('[data-shelf="2024"] .bs-shelf__row')!
    document.elementFromPoint = () => target

    await user.pointer([
      { keys: "[MouseLeft>]", target: spine("Now One"), coords: { clientX: 10, clientY: 10 } },
      { coords: { clientX: 60, clientY: 200 } },
      { keys: "[/MouseLeft]", coords: { clientX: 60, clientY: 200 } },
    ])

    expect(onMove).toHaveBeenCalledWith(expect.objectContaining({ id: "n1" }), "2024", 3)
    expect(onOpen).not.toHaveBeenCalled()
  })
})

describe("rows", () => {
  afterEach(() => vi.unstubAllGlobals())

  it("carries books that do not fit the bookcase width onto another row of the same shelf", () => {
    vi.stubGlobal(
      "ResizeObserver",
      class {
        constructor(private fire: (entries: { contentRect: { width: number } }[]) => void) {}
        observe() {
          this.fire([{ contentRect: { width: 200 } }])
        }
        disconnect() {}
      },
    )
    const many: Shelf[] = [{ key: "2024", count: 6, books: Array.from({ length: 6 }, (_, i) => book({ id: `r${i}` })) }]
    render(<Bookcase shelves={many} onOpen={() => {}} />)

    const rows = document.querySelectorAll('[data-shelf="2024"] .bs-shelf__row')
    expect(rows.length).toBeGreaterThan(1)
    expect([...rows].reduce((n, r) => n + r.querySelectorAll(".bs-spine").length, 0)).toBe(6)
    expect(document.querySelectorAll('[data-shelf="2024"] .bs-shelf__plank')).toHaveLength(rows.length)
  })
})
