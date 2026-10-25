import { book } from "@/test/fixtures"
import { arrangeShelves } from "./arrange"

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
