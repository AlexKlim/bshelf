import type { TFunction } from "i18next"
import type { BookSummary, Edition, Format, SearchResult, Status } from "./types"

const ru = (lng: string) => lng.startsWith("ru")

export const verbForm = (format: Format) => (format === "audio" ? "audio" : "ebook")

export function statusWord(t: TFunction, status: Status, format: Format) {
  return status === "in_progress" || status === "done" ? t(`status.${status}.${verbForm(format)}`) : t(`status.${status}`)
}

export function monthYear(iso: string, lng: string) {
  return new Intl.DateTimeFormat(lng, { month: ru(lng) ? "long" : "short", year: "numeric", timeZone: "UTC" })
    .format(new Date(iso))
    .replace(/\s*г\.$/, "")
}

export function monthOnly(iso: string, lng: string) {
  return new Intl.DateTimeFormat(lng, { month: ru(lng) ? "long" : "short", timeZone: "UTC" }).format(new Date(iso))
}

// "с мая 2025": Russian needs the genitive month, which Intl only produces next to a day.
export function sinceMonth(iso: string, lng: string) {
  const date = new Date(iso)
  if (!ru(lng)) return monthYear(iso, lng)
  const month = new Intl.DateTimeFormat(lng, { day: "numeric", month: "long", timeZone: "UTC" })
    .formatToParts(date)
    .find((p) => p.type === "month")!.value
  return `${month} ${date.getUTCFullYear()}`
}

export const yearOf = (iso: string) => new Date(iso).getUTCFullYear()

const STATUS_RANK: Record<Status, number> = { in_progress: 0, done: 1, owned: 2, want: 3 }

export function primaryEdition(book: Pick<BookSummary, "editions">): Edition | undefined {
  return [...book.editions]
    .filter((e) => e.status)
    .sort(
      (a, b) =>
        STATUS_RANK[a.status!] - STATUS_RANK[b.status!] || (b.finished_at ?? "").localeCompare(a.finished_at ?? ""),
    )[0]
}

export function statusDate(edition: Edition) {
  switch (edition.status) {
    case "done":
      return edition.finished_at
    case "in_progress":
      return edition.started_at ?? edition.status_updated_at
    case "owned":
      return edition.purchased_at ?? edition.status_updated_at
    default:
      return edition.status_updated_at
  }
}

export function statusLine(
  t: TFunction,
  lng: string,
  edition: Edition | undefined,
  { monthOnly: short = false, separator = " · " } = {},
) {
  if (!edition?.status) return ""
  const status = statusWord(t, edition.status, edition.format)
  const date = statusDate(edition)
  if (!date) return status
  if (edition.status === "done") {
    return `${status}${separator}${short ? monthOnly(date, lng) : monthYear(date, lng)}`
  }
  return t("line.since", { status, date: sinceMonth(date, lng), sep: separator })
}

export function formatsOf(book: Pick<BookSummary, "editions">) {
  const formats = new Set(book.editions.map((e) => verbForm(e.format)))
  return (["audio", "ebook"] as const).filter((f) => formats.has(f))
}

export function answerLine(t: TFunction, lng: string, result: SearchResult) {
  const { answer } = result
  const book = result.books.find((b) => "book_id" in answer && b.id === answer.book_id) ?? result.books[0]
  const done = (format: "audio" | "ebook") =>
    (book?.editions ?? [])
      .filter((e) => e.status === "done" && verbForm(e.format) === format && e.finished_at)
      .map((e) => e.finished_at!)
      .sort()
      .at(-1)

  switch (answer.kind) {
    case "listened":
    case "read": {
      const date = done(answer.kind === "listened" ? "audio" : "ebook")
      const word = t(`answer.${answer.kind}`)
      return date ? `${word} · ${monthYear(date, lng)}` : word
    }
    case "read_and_listened": {
      const years = [done("ebook"), done("audio")].filter(Boolean).map((d) => yearOf(d!))
      const unique = [...new Set(years)].sort()
      return [t("answer.read_and_listened"), unique.join(", ")].filter(Boolean).join(" · ")
    }
    case "in_progress": {
      const edition = book?.editions.find((e) => e.status === "in_progress")
      return t(`status.in_progress.${verbForm(edition?.format ?? "unknown")}`)
    }
    case "owned":
      return t("status.owned")
    case "want": {
      const date = book?.editions.find((e) => e.status === "want")?.status_updated_at
      return date ? t("answer.want_since", { date: sinceMonth(date, lng) }) : t("answer.want")
    }
    case "similar":
      return t("answer.similar", { count: answer.count })
    case "not_found":
      return t("answer.not_found")
  }
}

export function syncResult(t: TFunction, r: { books: number; highlights: number }) {
  return t("sources.result", {
    books: t("count.books", { count: r.books }),
    highlights: t("count.highlights", { count: r.highlights }),
  })
}

export function errorMessage(t: TFunction, e: unknown) {
  const code = (e as { code?: string } | null)?.code ?? "generic"
  return t(`errors.${code}`, { defaultValue: t("errors.generic") })
}
