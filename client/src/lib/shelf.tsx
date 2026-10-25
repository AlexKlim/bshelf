import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from "react"
import { getShelfPage, getShelves } from "@/api"
import type { ApiError } from "./api"
import { readCache, writeCache } from "./cache"
import type { Shelf, ShelfKey } from "./types"

type State = { shelves: Shelf[] | null; fromCache: boolean; error: string | null }
type ShelfData = State & { reload: () => Promise<void>; loadMore: (key: ShelfKey) => void }

const ShelfContext = createContext<ShelfData>({
  shelves: null,
  fromCache: false,
  error: null,
  reload: async () => {},
  loadMore: () => {},
})

export function ShelfProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<State>({ shelves: null, fromCache: false, error: null })
  const loading = useRef(new Set<ShelfKey>())

  const reload = useCallback(async () => {
    try {
      const { shelves } = await getShelves()
      writeCache("shelf", shelves)
      setState({ shelves, fromCache: false, error: null })
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
          const known = new Set(current.books.map((b) => b.id))
          const fresh = page.books.filter((b) => !known.has(b.id))
          if (!fresh.length) return prev
          const next = { ...current, count: page.count, books: [...current.books, ...fresh] }
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

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    reload()
    window.addEventListener("online", reload)
    return () => window.removeEventListener("online", reload)
  }, [reload])

  return <ShelfContext.Provider value={{ ...state, reload, loadMore }}>{children}</ShelfContext.Provider>
}

// eslint-disable-next-line react-refresh/only-export-components
export const useShelf = () => useContext(ShelfContext)
