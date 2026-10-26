import type { CSSProperties } from "react"
import type { BookSummary } from "./types"

export function hash(id: string) {
  let h = 2166136261
  for (let i = 0; i < id.length; i++) {
    h ^= id.charCodeAt(i)
    h = Math.imul(h, 16777619)
  }
  return h >>> 0
}

const clamp = (n: number) => Math.min(1, Math.max(0, n))

type Sized = Pick<BookSummary, "id" | "page_count" | "audio_minutes">

export function spineSize(book: Sized) {
  const h = hash(book.id)
  const t = book.page_count
    ? (book.page_count - 150) / 650
    : book.audio_minutes
      ? (book.audio_minutes - 180) / 1320
      : 0.15 + ((h >>> 12) % 5) / 10
  const width = Math.round(28 + 16 * clamp(t))
  const height = 136 + ((h >>> 4) % 7) * 8
  return { width, height, narrow: width < 30 }
}

export function bookLang(book: { title: string; language?: string | null }) {
  return book.language || (/[а-яё]/i.test(book.title) ? "ru" : "en")
}

export const clothStyle = (book: { cloth_color?: string | null }) =>
  (book.cloth_color ? { "--cloth-color": book.cloth_color } : {}) as CSSProperties
