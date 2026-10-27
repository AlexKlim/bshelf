import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from "react"
import { getShelfPage, getShelves } from "@/api"
import type { ApiError } from "./api"
import { placeBook, removeBook, swapBook } from "./arrange"
import { readCache, writeCache } from "./cache"
import type { BookSummary, Shelf, ShelfKey } from "./types"

function addPage(shelf: Shelf, page: { count: number; books: BookSummary[] }): Shelf {
  const known = new Set(shelf.books.map((b) => b.id))
  return { ...shelf, count: page.count, books: [...shelf.books, ...page.books.filter((b) => !known.has(b.id))] }
}

async function refill(shelf: Shelf, length: number) {
  let current = shelf
  while (current.books.length < Math.min(length, current.count)) {
    const page = await getShelfPage(current.key, current.books.length).catch(() => null)
    if (!page) break
    const next = addPage(current, page)
    if (next.books.length === current.books.length) return next
    current = next
  }
  return current
}

type State = { shelves: Shelf[] | null; fromCache: boolean; error: string | null }
type ShelfData = State & {
  reload: () => Promise<void>
  loadMore: (key: ShelfKey) => void
  place: (book: BookSummary, before?: string, after?: string) => void
  swap: (book: BookSummary) => void
  remove: (id: string) => void
}

const ShelfContext = createContext<ShelfData>({
  shelves: null,
  fromCache: false,
  error: null,
  reload: async () => {},
  loadMore: () => {},
  place: () => {},
  swap: () => {},
  remove: () => {},
})

export function ShelfProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<State>({ shelves: null, fromCache: false, error: null })
  const loading = useRef(new Set<ShelfKey>())
  const shown = useRef<Shelf[] | null>(null)
  useEffect(() => {
    shown.current = state.shelves
  }, [state.shelves])

  const reload = useCallback(async () => {
    try {
      const { shelves } = await getShelves()
      writeCache("shelf", shelves)
      const lengths = new Map(shown.current?.map((s) => [s.key, s.books.length]))
      const full = await Promise.all(shelves.map((s) => refill(s, lengths.get(s.key) ?? 0)))
      setState({ shelves: full, fromCache: false, error: null })
    } catch (e) {
      const cached = readCache<Shelf[]>("shelf")
      setState({ shelves: cached, fromCache: !!cached, error: (e as ApiError).code })
    }
  }, [])

  // The bookcase folds "owned" into "want", so the end of "want" pages through both.
  const loadMore = useCallback(
    async (key: ShelfKey) => {
      const shelf = (key === "want" ? ["want", "owned"] : [key])
        .map((k) => state.shelves?.find((s) => s.key === k))
        .find((s) => s && s.books.length < s.count)
      if (!shelf || loading.current.has(shelf.key)) return
      loading.current.add(shelf.key)
      try {
        const page = await getShelfPage(shelf.key, shelf.books.length)
        setState((prev) => {
          const current = prev.shelves?.find((s) => s.key === shelf.key)
          if (!current) return prev
          const next = addPage(current, page)
          return { ...prev, shelves: prev.shelves!.map((s) => (s === current ? next : s)) }
        })
      } catch {
        // the next time the end of the shelf comes into view asks again
      } finally {
        loading.current.delete(shelf.key)
      }
    },
    [state.shelves],
  )

  const place = useCallback((book: BookSummary, before?: string, after?: string) => {
    setState((prev) => (prev.shelves ? { ...prev, shelves: placeBook(prev.shelves, book, before, after) } : prev))
  }, [])
  const swap = useCallback((book: BookSummary) => {
    setState((prev) => (prev.shelves ? { ...prev, shelves: swapBook(prev.shelves, book) } : prev))
  }, [])
  const remove = useCallback((id: string) => {
    setState((prev) => (prev.shelves ? { ...prev, shelves: removeBook(prev.shelves, id) } : prev))
  }, [])

  useEffect(() => {
    reload()
    window.addEventListener("online", reload)
    return () => window.removeEventListener("online", reload)
  }, [reload])

  return <ShelfContext.Provider value={{ ...state, reload, loadMore, place, swap, remove }}>{children}</ShelfContext.Provider>
}

// eslint-disable-next-line react-refresh/only-export-components
export const useShelf = () => useContext(ShelfContext)
