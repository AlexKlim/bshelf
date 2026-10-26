import { book, edition as fixture } from "@/test/fixtures"
import { arrangeShelves, placeBook, shelfStatus } from "./arrange"
import type { Edition, Shelf } from "./types"

const books = (prefix: string, n: number) => Array.from({ length: n }, (_, i) => book({ id: `${prefix}${i}` }))
const ids = (prefix: string, n: number) => books(prefix, n).map((b) => b.id)

describe("arrangeShelves", () => {
  it("keeps owned books off Want until every wanted book is loaded, so paging never slips wanted books in front of them", () => {
    const partial = arrangeShelves([
      { key: "want", count: 45, books: books("w", 40) },
      { key: "owned", count: 3, books: books("o", 3) },
    ])
    const want = partial.find((s) => s.key === "want")!
    expect(want.count).toBe(48)
    expect(want.books.map((b) => b.id)).toEqual(ids("w", 40))

    const complete = arrangeShelves([
      { key: "want", count: 45, books: books("w", 45) },
      { key: "owned", count: 3, books: books("o", 3) },
    ])
    expect(complete.find((s) => s.key === "want")!.books.map((b) => b.id)).toEqual([...ids("w", 45), ...ids("o", 3)])
  })
})

describe("shelfStatus", () => {
  const today = new Date(2026, 9, 26)
  const edition = (over: Partial<Edition> = {}) => fixture(over)

  it("turns the shelf a book is dropped on into a status", () => {
    expect(shelfStatus(edition(), "now", today)).toEqual({ status: "in_progress" })
    expect(shelfStatus(edition({ store: null }), "want", today)).toEqual({ status: "want" })
    expect(shelfStatus(edition({ store: "litres" }), "want", today)).toEqual({ status: "owned" })
    expect(shelfStatus(edition(), "no_date", today)).toEqual({ status: "done", finished_at: "" })
    expect(shelfStatus(edition(), "2026", today)).toEqual({ status: "done", finished_at: "2026-10-26" })
    expect(shelfStatus(edition(), "2019", today)).toEqual({ status: "done", finished_at: "2019-12-31" })
    expect(shelfStatus(edition({ status: "done", finished_at: "2019-03-02T10:00:00Z" }), "2019", today)).toEqual({ status: "done" })
  })
})

describe("placeBook", () => {
  it("takes the book off its shelf and puts it first on the new one", () => {
    const moved = book({ id: "m", shelf: "2026" })
    const shelves: Shelf[] = [
      { key: "now", count: 2, books: [book({ id: "a" }), { ...moved, shelf: "now" }] },
      { key: "2026", count: 1, books: [book({ id: "b" })] },
    ]

    const placed = placeBook(shelves, moved)

    expect(placed.map((s) => [s.key, s.count, s.books.map((b) => b.id)])).toEqual([
      ["now", 1, ["a"]],
      ["2026", 2, ["m", "b"]],
    ])
    expect(placeBook(shelves, { ...moved, shelf: "no_date" }).at(-1)).toEqual({ key: "no_date", count: 1, books: [{ ...moved, shelf: "no_date" }] })
  })
})

describe("placeBook between neighbours", () => {
  it("puts the book right after the one shown before it, or right before the one after it", () => {
    const shelves: Shelf[] = [{ key: "now", count: 3, books: ["a", "b", "c"].map((id) => book({ id, shelf: "now" })) }]
    const moved = book({ id: "m", shelf: "now" })
    const ids = (placed: Shelf[]) => placed[0].books.map((b) => b.id)

    expect(ids(placeBook(shelves, moved, "b", "c"))).toEqual(["a", "b", "m", "c"])
    expect(ids(placeBook(shelves, moved, undefined, "a"))).toEqual(["m", "a", "b", "c"])
    expect(ids(placeBook(shelves, moved, "c"))).toEqual(["a", "b", "c", "m"])
  })
})
