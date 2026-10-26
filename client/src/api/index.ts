import { api } from "@/lib/api"
import type {
  ApiToken,
  Assistant,
  Banner,
  Duplicate,
  RemoteSession,
  ShareAnswer,
  ShareSuggestion,
  BookDetail,
  BookSummary,
  Format,
  Highlight,
  Note,
  SearchResult,
  Shelf,
  ShelfKey,
  Source,
  Stats,
  Status,
  User,
} from "@/lib/types"

const post = <T>(path: string, body?: unknown) => api<T>(path, { method: "POST", body })
const patch = <T>(path: string, body?: unknown) => api<T>(path, { method: "PATCH", body })
const del = (path: string) => api<void>(path, { method: "DELETE" })

export const register = (email: string, password: string) => post<void>("/registration", { email, password })
export const confirmEmail = (token: string) => post<void>("/confirmation", { token })
export const resendConfirmation = (email: string) => post<void>("/confirmation/resend", { email })
export const requestPasswordReset = (email: string) => post<void>("/password", { email })
export const resetPassword = (token: string, password: string) => patch<void>("/password", { token, password })
export const signIn = (email: string, password: string) => post<{ user: User }>("/session", { email, password })
export const signOut = () => del("/session")
export const me = () => api<{ user: User }>("/me")
export const deleteAccount = () => del("/me")
export const changePassword = (currentPassword: string, password: string) =>
  patch<void>("/me/password", { current_password: currentPassword, password })

export const listTokens = () => api<{ api_tokens: ApiToken[] }>("/api_tokens")
export const createToken = (name: string) => post<{ api_token: ApiToken; token: string }>("/api_tokens", { name })
export const revokeToken = (id: string) => del(`/api_tokens/${id}`)

const SHELF_PAGE = 40
export const getShelves = () => api<{ shelves: Shelf[] }>(`/shelf?limit=${SHELF_PAGE}`)
export const getShelfPage = (key: ShelfKey, offset: number) =>
  api<Shelf>(`/shelf/${key}?offset=${offset}&limit=${SHELF_PAGE}`)
export const search = (q: string) => api<SearchResult>(`/search?q=${encodeURIComponent(q)}`)

export type NewBook = {
  title: string
  author?: string
  edition: { format: Format; status: Status; started_at?: string; finished_at?: string }
}
export const addBook = (book: NewBook) => post<{ book: BookDetail }>("/books", book)
export const getBook = (id: string) => api<{ book: BookDetail }>(`/books/${id}`)
export const updateEdition = (id: string, body: { status: Status; started_at?: string; finished_at?: string }) =>
  patch<{ book: BookSummary }>(`/editions/${id}`, body)

export const addNote = (bookId: string, body: string) => post<{ note: Note }>(`/books/${bookId}/notes`, { body })
export const updateNote = (id: string, body: string) => patch<{ note: Note }>(`/notes/${id}`, { body })
export const deleteNote = (id: string) => del(`/notes/${id}`)
export const getHighlights = (bookId: string, offset: number) =>
  api<{ highlights: Highlight[]; count: number }>(`/books/${bookId}/highlights?offset=${offset}&limit=50`)

export const addEdition = (bookId: string, edition: NewBook["edition"] & { store?: "litres" | "amazon" }) =>
  post<{ book: BookDetail }>(`/books/${bookId}/editions`, { edition })
export const mergeBooks = (id: string, otherId: string) =>
  post<{ book: BookDetail; merge_id: string }>(`/books/${id}/merge`, { other_id: otherId })
export const unmerge = (mergeId: string) => api<{ books: BookSummary[] }>(`/merges/${mergeId}`, { method: "DELETE" })
export const getDuplicates = () => api<{ duplicates: Duplicate[] }>("/duplicates")
export const dismissDuplicate = (id: string) => del(`/duplicates/${id}`)

export const getAssistants = () =>
  api<{ assistants: Assistant[]; gemini_client: { client_id: string; created_at: string } | null }>("/assistants")
export const revokeAssistant = (id: string) => del(`/assistants/${id}`)
export const createGeminiClient = () => post<{ client_id: string; client_secret: string }>("/assistants/gemini_client")
export const revokeGeminiClient = () => del("/assistants/gemini_client")

export const getStats = (year?: number) => api<Stats>(year ? `/stats?year=${year}` : "/stats")
export const getSources = () => api<{ sources: Source[]; banner: Banner | null }>("/sources")

export const share = (fields: { url?: string; text?: string; title?: string; locale: string }) =>
  post<ShareAnswer>("/share", fields)
export const shareAdd = (
  suggestion: ShareSuggestion & { title: string },
  edition: { format: Format; status: Status },
  locale: string,
) =>
  post<{ book: BookSummary; message: string }>("/share/add", {
    title: suggestion.title,
    author: suggestion.author ?? undefined,
    edition: { ...edition, store: suggestion.store ?? undefined, external_id: suggestion.external_id ?? undefined },
    locale,
  })

export const startRemoteSession = (purpose: RemoteSession["purpose"], viewport: { width: number; height: number }) =>
  post<{ session: RemoteSession }>("/remote_browser_sessions", { purpose, disclosure_accepted: true, viewport })
export const getRemoteSession = (id: string) => api<{ session: RemoteSession }>(`/remote_browser_sessions/${id}`)
export const cancelRemoteSession = (id: string) => api<{ session: RemoteSession }>(`/remote_browser_sessions/${id}`, { method: "DELETE" })
export const remoteViewer = (id: string) => post<{ url: string; expires_at: string }>(`/remote_browser_sessions/${id}/viewer`)
