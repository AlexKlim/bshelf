import type { TFunction } from "i18next"
import type { Shelf, ShelfKey } from "./types"

// The bookcase has no "owned" shelf: bought-but-unstarted books stand on "Want" after the wanted ones,
// their caption still says "Owned". "Now" and "Want" are always on the case so it keeps its shape.
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
