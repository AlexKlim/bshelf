import type { BookSummary, Cloth } from "./types"

export const CLOTHS: Cloth[] = ["oxblood", "bottle", "navy", "plum", "slate", "ochre", "sage", "linen"]

export function hash(id: string) {
  let h = 2166136261
  for (let i = 0; i < id.length; i++) {
    h ^= id.charCodeAt(i)
    h = Math.imul(h, 16777619)
  }
  return h >>> 0
}

let table: number[] | undefined

// Same fallback as the server (Zlib.crc32 of the uuid), so a coverless book keeps its cloth where the API omits it.
export function crc32(text: string) {
  table ??= Array.from({ length: 256 }, (_, n) => {
    let c = n
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1
    return c >>> 0
  })
  let crc = 0xffffffff
  for (const byte of new TextEncoder().encode(text)) crc = table[(crc ^ byte) & 0xff] ^ (crc >>> 8)
  return (crc ^ 0xffffffff) >>> 0
}

export function clothFor(book: { id: string; cloth?: Cloth | null }): Cloth {
  return book.cloth ?? CLOTHS[crc32(book.id) % CLOTHS.length]
}

const clamp = (n: number) => Math.min(1, Math.max(0, n))

type Sized = Pick<BookSummary, "id" | "page_count" | "audio_minutes">

// Width follows length (tokens: 150-800 pages, 3-25 hours); unknown length gets a stable middle width.
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
