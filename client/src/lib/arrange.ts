import type { TFunction } from "i18next"
import type { Edition, Shelf, ShelfKey, Status } from "./types"

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
