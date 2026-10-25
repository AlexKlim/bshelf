import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from "react"
import { getShelves } from "@/api"
import type { ApiError } from "./api"
import { readCache, writeCache } from "./cache"
import type { Shelf } from "./types"

type State = { shelves: Shelf[] | null; fromCache: boolean; error: string | null }
type ShelfData = State & { reload: () => Promise<void> }

const ShelfContext = createContext<ShelfData>({ shelves: null, fromCache: false, error: null, reload: async () => {} })

export function ShelfProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<State>({ shelves: null, fromCache: false, error: null })

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

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    reload()
    window.addEventListener("online", reload)
    return () => window.removeEventListener("online", reload)
  }, [reload])

  return <ShelfContext.Provider value={{ ...state, reload }}>{children}</ShelfContext.Provider>
}

// eslint-disable-next-line react-refresh/only-export-components
export const useShelf = () => useContext(ShelfContext)
