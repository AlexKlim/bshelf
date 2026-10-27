import type { TFunction } from "i18next"
import type { BookSummary, Edition, Shelf, ShelfKey, Status } from "./types"

export function arrangeShelves(shelves: Shelf[]): Shelf[] {
  const byKey = new Map(shelves.map((s) => [s.key, s]))
  const owned = byKey.get("owned")
  const want = byKey.get("want")
  const now = byKey.get("now") ?? { key: "now", count: 0, books: [] }
  const wantBooks = want?.books ?? []
  const mergedWant: Shelf = {
    key: "want",
    count: (want?.count ?? 0) + (owned?.count ?? 0),
    books: wantBooks.length === (want?.count ?? 0) ? [...wantBooks, ...(owned?.books ?? [])] : wantBooks,
  }
  const rest = shelves.filter((s) => !["now", "want", "owned"].includes(s.key))
  return [now, mergedWant, ...rest]
}

export function shelfLabel(t: TFunction, key: ShelfKey) {
  if (key === "now") return t("shelf.now")
  if (key === "want") return t("shelf.want")
  if (key === "owned") return t("shelf.owned")
  if (key === "no_date") return t("shelf.noDate")
  return key
}

export const isYear = (key: ShelfKey) => /^\d{4}$/.test(key)

export const isEmptyCase = (shelves: Shelf[]) => shelves.every((s) => s.count === 0)

const isoDay = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`

export function shelfStatus(edition: Edition, key: ShelfKey, today = new Date()): { status: Status; finished_at?: string } {
  if (key === "now") return { status: "in_progress" }
  if (key === "want" || key === "owned") return { status: edition.store ? "owned" : "want" }
  if (key === "no_date") return { status: "done", finished_at: "" }
  if (edition.status === "done" && edition.finished_at?.startsWith(key)) return { status: "done" }
  // A past year has no day to go by, so the book lands on its last day.
  return { status: "done", finished_at: Number(key) === today.getFullYear() ? isoDay(today) : `${key}-12-31` }
}

export function movedBook(book: BookSummary, to: ShelfKey, changes: ReturnType<typeof shelfStatus>[]): BookSummary {
  const editions = book.editions.map((e, i) => {
    const { status, finished_at } = changes[i]
    return { ...e, status, finished_at: finished_at === undefined ? e.finished_at : finished_at || null }
  })
  return { ...book, shelf: to, editions }
}

export function placeBook(shelves: Shelf[], book: BookSummary, before?: string, after?: string): Shelf[] {
  const placed = shelves.map((s) => {
    const had = s.books.some((b) => b.id === book.id)
    const books = s.books.filter((b) => b.id !== book.id)
    if (s.key !== book.shelf) return had ? { ...s, count: s.count - 1, books } : s
    const left = books.findIndex((b) => b.id === before)
    const right = books.findIndex((b) => b.id === after)
    const at = left >= 0 ? left + 1 : Math.max(right, 0)
    return { ...s, count: s.count + (had ? 0 : 1), books: [...books.slice(0, at), book, ...books.slice(at)] }
  })
  return placed.some((s) => s.key === book.shelf) ? placed : [...placed, { key: book.shelf, count: 1, books: [book] }]
}

export const removeBook = (shelves: Shelf[], id: string): Shelf[] =>
  shelves.map((s) => (s.books.some((b) => b.id === id) ? { ...s, count: s.count - 1, books: s.books.filter((b) => b.id !== id) } : s))

export const swapBook = (shelves: Shelf[], book: BookSummary): Shelf[] =>
  shelves.map((s) => (s.books.some((b) => b.id === book.id) ? { ...s, books: s.books.map((b) => (b.id === book.id ? book : b)) } : s))
