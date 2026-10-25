import type { BookSummary, Edition } from "@/lib/types"

let seq = 0

export function edition(overrides: Partial<Edition> = {}): Edition {
  return {
    id: `e${++seq}`,
    format: "audio",
    store: null,
    source: "manual",
    purchased_at: null,
    status: "done",
    status_source: "manual",
    status_updated_at: "2025-05-04T00:00:00.000Z",
    started_at: null,
    finished_at: "2024-03-10T00:00:00.000Z",
    total_minutes: null,
    ...overrides,
  }
}

export function book(overrides: Partial<BookSummary> = {}): BookSummary {
  const id = overrides.id ?? `b${++seq}`
  return {
    id,
    title: `Book ${id}`,
    author: "Author",
    original_title: null,
    language: "en",
    year: null,
    page_count: null,
    audio_minutes: null,
    cover_url: null,
    cloth: "navy",
    shelf: "2024",
    bought_twice: false,
    editions: [edition()],
    ...overrides,
  }
}

export function mockFetch(handler: (url: string, init: RequestInit) => [number, unknown]) {
  const fn = vi.fn(async (url: string, init: RequestInit = {}) => {
    const [status, body] = handler(url, init)
    return new Response(status === 204 ? null : JSON.stringify(body), { status })
  })
  vi.stubGlobal("fetch", fn)
  return fn
}
