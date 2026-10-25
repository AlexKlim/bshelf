import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from "react"
import { me } from "@/api"
import { ApiError, UNAUTHORIZED_EVENT } from "./api"
import { readCache, writeCache, clearCaches } from "./cache"
import type { User } from "./types"

type Session = { user: User | null | undefined; setUser: (user: User | null) => void }

const SessionContext = createContext<Session>({ user: undefined, setUser: () => {} })

export function SessionProvider({ children, initialUser }: { children: ReactNode; initialUser?: User | null }) {
  const [user, setUserState] = useState<User | null | undefined>(initialUser)

  const setUser = useCallback((next: User | null) => {
    if (next) writeCache("user", next)
    else clearCaches()
    setUserState(next)
  }, [])

  useEffect(() => {
    if (initialUser !== undefined) return
    me()
      .then(({ user }) => setUser(user))
      .catch((e: ApiError) => {
        // Offline launch: trust the last known user so the cached bookcase can show.
        setUserState(e.code === "network" ? readCache<User>("user") : null)
      })
  }, [initialUser, setUser])

  useEffect(() => {
    const onUnauthorized = () => setUser(null)
    window.addEventListener(UNAUTHORIZED_EVENT, onUnauthorized)
    return () => window.removeEventListener(UNAUTHORIZED_EVENT, onUnauthorized)
  }, [setUser])

  return <SessionContext.Provider value={{ user, setUser }}>{children}</SessionContext.Provider>
}

// eslint-disable-next-line react-refresh/only-export-components
export const useSession = () => useContext(SessionContext)
