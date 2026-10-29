// Mirrors API.md. Keep both in sync.
export type Status = "want" | "owned" | "in_progress" | "done"
export type Format = "audio" | "ebook" | "personal_doc" | "unknown"
export type ShelfKey = "now" | "want" | "owned" | "no_date" | `${number}`
export type Cloth = "oxblood" | "bottle" | "navy" | "plum" | "slate" | "ochre" | "sage" | "linen"

export type User = { id: string; email: string; created_at: string }
export type ApiToken = { id: string; name: string; created_at: string; last_used_at: string | null }
export type Assistant = {
  id: string
  name: string
  client_id: string
  scopes: string[]
  connected_at: string
  last_active_at: string | null
}
export type Duplicate = { id: string; reason: "title_author" | "title" | "translation"; created_at: string; books: [BookSummary, BookSummary] }

export type Edition = {
  id: string
  format: Format
  store: "litres" | "amazon" | "storytel" | null
  source: "manual" | "share" | "mcp" | "litres" | "kindle_export" | "kindle_browser" | "storytel"
  purchased_at: string | null
  status: Status | null
  status_source: "manual" | "litres" | "kindle_browser" | "kindle_export" | "purchase" | "storytel" | null
  status_updated_at: string | null
  started_at: string | null
  finished_at: string | null
  total_minutes: number | null
}

export type BookSummary = {
  id: string
  title: string
  author: string | null
  original_title: string | null
  language: string | null
  year: number | null
  page_count: number | null
  audio_minutes: number | null
  cover_url: string | null
  cloth: Cloth
  cloth_color?: string | null
  shelf: ShelfKey
  bought_twice?: boolean
  editions: Edition[]
}

export type Note = { id: string; body: string; created_at: string; updated_at: string }
export type Highlight = {
  id: string
  text: string
  note: string | null
  location: string | null
  source: string
  highlighted_at: string | null
}

export type BookDetail = BookSummary & {
  isbn: string | null
  match_source: string
  notes: Note[]
  highlights: Highlight[]
  highlights_count: number
  merges?: { id: string; title: string; author: string | null; created_at: string }[]
}

export type Shelf = { key: ShelfKey; count: number; books: BookSummary[] }

export type SearchAnswer =
  | { kind: "listened" | "read" | "read_and_listened" | "in_progress" | "owned" | "want"; book_id: string }
  | { kind: "similar"; count: number }
  | { kind: "not_found" }

export type SearchResult = { query: string; answer: SearchAnswer; books: BookSummary[] }

export type StatsBook = {
  id: string
  cloth?: Cloth
  cloth_color?: string | null
  title: string
  author: string | null
  formats: Format[]
  finished_at: string
  minutes: number | null
}

export const GENRES = ["fiction", "fantasy", "crime", "psychology", "business", "science", "history", "other"] as const
export type Genre = (typeof GENRES)[number]

export type Stats = {
  year: number
  years: number[]
  total: number
  listened?: number
  read?: number
  by_format: Partial<Record<Format, number>>
  by_genre?: Partial<Record<Genre, number>>
  total_minutes: number | null
  months: { month: number; books: StatsBook[] }[]
  no_date_count: number
  top_authors: { author: string; count: number }[]
}

export type RemoteInterruption = "aborted" | "timeout" | "provider_refused" | "deploy_interrupted" | "browser_failed"
export type RemoteStatus = "queued" | "connecting" | "live" | "collecting" | "done" | "interrupted"
export type RemoteResult = { books: number; highlights: number }

export type RemoteSession = {
  id: string
  purpose: "kindle" | "litres" | "storytel"
  status: RemoteStatus
  queue_position?: number | null
  expires_at?: string | null
  seconds_left?: number | null
  login_window_seconds?: number | null
  created_at?: string
  steps: { key: string; state: "done" | "pending" }[]
  result: RemoteResult | null
  interruption: RemoteInterruption | null
}

export type Source = {
  kind: "litres" | "storytel" | "kindle_browser"
  status: "never" | "ok" | "error" | "needs_login"
  last_sync_at: string | null
  error: string | null
  books_count: number
  session: { id: string; status: RemoteStatus; result: RemoteResult | null; interruption: RemoteInterruption | null } | null
}

export type Banner =
  | { kind: "source_error"; source: Source["kind"]; error: string; dismissible: false; key: string }
  | { kind: "litres_reminder"; dismissible: boolean; key: string }
  | { kind: "possible_duplicates"; count: number; dismissible: boolean; key: string }

export type ShareSuggestion = { title: string | null; author: string | null; store: "litres" | "amazon" | null; external_id: string | null }
export type ShareAnswer = Omit<SearchResult, "answer"> & {
  answer: SearchAnswer | { kind: "unrecognized" }
  message: string
  link: { store: string; external_id: string } | null
  suggestion: ShareSuggestion | null
}
