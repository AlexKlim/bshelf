// Mirrors API.md. Keep both in sync.
export type Status = "want" | "owned" | "in_progress" | "done"
export type Format = "audio" | "ebook" | "personal_doc" | "unknown"
export type ShelfKey = "now" | "want" | "owned" | "no_date" | `${number}`

export type User = { id: string; email: string; created_at: string }
export type ApiToken = { id: string; name: string; created_at: string; last_used_at: string | null }

export type Edition = {
  id: string
  format: Format
  store: "litres" | "amazon" | null
  source: "manual" | "share" | "mcp" | "litres" | "kindle_export" | "kindle_browser"
  purchased_at: string | null
  status: Status | null
  status_source: "manual" | "litres" | "kindle_browser" | "kindle_export" | "purchase" | null
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
  shelf: ShelfKey
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
}

export type Shelf = { key: ShelfKey; count: number; books: BookSummary[] }

export type SearchAnswer =
  | { kind: "listened" | "read" | "read_and_listened" | "in_progress" | "owned" | "want"; book_id: string }
  | { kind: "similar"; count: number }
  | { kind: "not_found" }

export type SearchResult = { query: string; answer: SearchAnswer; books: BookSummary[] }

export type StatsBook = {
  id: string
  title: string
  author: string | null
  formats: Format[]
  finished_at: string
  minutes: number | null
}

export type Stats = {
  year: number
  years: number[]
  total: number
  by_format: Partial<Record<Format, number>>
  total_minutes: number | null
  months: { month: number; books: StatsBook[] }[]
  no_date_count: number
  top_authors: { author: string; count: number }[]
}

export type Source = {
  kind: "litres" | "kindle_export" | "kindle_browser"
  status: "never" | "ok" | "error" | "needs_login"
  last_sync_at: string | null
  error: string | null
}
