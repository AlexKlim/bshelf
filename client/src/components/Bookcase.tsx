import { memo, useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState, type CSSProperties, type KeyboardEvent } from "react"
import { useTranslation } from "react-i18next"
import { shelfLabel } from "@/lib/arrange"
import { bookLang, clothFor, spineSize } from "@/lib/cloth"
import type { BookSummary, Shelf, ShelfKey } from "@/lib/types"
import { useMediaQuery } from "@/lib/useMediaQuery"
import { formatsOf, primaryEdition, statusLine } from "@/lib/vocab"
import { Ico, ShelfEnd, StatusMark } from "./ui"

type Props = {
  shelves: Shelf[]
  matches?: ReadonlySet<string>
  onOpen: (book: BookSummary) => void
  onMore?: (key: ShelfKey) => void
}

const FADE = 24

function revealInRow(spine: HTMLElement, smooth: boolean) {
  const row = spine.closest<HTMLElement>(".bs-shelf__row")
  if (!row) return
  const s = spine.getBoundingClientRect()
  const r = row.getBoundingClientRect()
  const left = s.left < r.left ? s.left - r.left - FADE : s.right > r.right - FADE ? s.right - r.right + 2 * FADE : 0
  if (left) row.scrollBy({ left, behavior: smooth ? "smooth" : "auto" })
}

export function Bookcase({ shelves, matches, onOpen, onMore }: Props) {
  const { t, i18n } = useTranslation()
  const lng = i18n.language
  const hover = !useMediaQuery("(pointer: coarse)")
  const reduced = useMediaQuery("(prefers-reduced-motion: reduce)")
  const [pulled, setPulled] = useState<string | null>(null)
  const [focus, setFocus] = useState<[number, number] | null>(null)
  const [captionX, setCaptionX] = useState(0)
  const spines = useRef(new Map<string, HTMLButtonElement>())
  const sections = useRef(new Map<string, HTMLElement>())
  const latest = useRef({ shelves, pulled, hover, onOpen })
  useLayoutEffect(() => {
    latest.current = { shelves, pulled, hover, onOpen }
  })

  const labels = useMemo(() => {
    const byId = new Map<string, string>()
    for (const shelf of shelves) {
      for (const book of shelf.books) {
        const status = statusLine(t, lng, primaryEdition(book), { separator: ", " })
        byId.set(book.id, `${book.title}${book.author ? `, ${book.author}` : ""}. ${status}`)
      }
    }
    return byId
  }, [shelves, t, lng])

  const firstShelf = shelves.findIndex((s) => s.books.length > 0)
  const [fs, fb] = focus && shelves[focus[0]]?.books[focus[1]] ? focus : [firstShelf, 0]
  const tabbable = shelves[fs]?.books[fb]?.id

  const pulledShelf = shelves.find((s) => s.books.some((b) => b.id === pulled))
  const pulledBook = pulledShelf?.books.find((b) => b.id === pulled)

  useEffect(() => {
    if (!pulled || hover) return
    const spine = spines.current.get(pulled)
    const section = pulledShelf && sections.current.get(pulledShelf.key)
    if (spine && section) setCaptionX(spine.getBoundingClientRect().left - section.getBoundingClientRect().left - 8)
    const clear = (e: PointerEvent) => {
      if (!(e.target as Element).closest?.(".bs-spine, .bs-caption")) setPulled(null)
    }
    window.addEventListener("pointerdown", clear)
    return () => window.removeEventListener("pointerdown", clear)
  }, [pulled, hover, pulledShelf])

  useEffect(() => {
    if (!matches?.size) return
    for (const shelf of latest.current.shelves) {
      const first = shelf.books.find((b) => matches.has(b.id))
      const spine = first && spines.current.get(first.id)
      if (spine) revealInRow(spine, !reduced)
    }
  }, [matches, reduced])

  const register = useCallback((id: string, el: HTMLButtonElement | null) => {
    if (el) spines.current.set(id, el)
    else spines.current.delete(id)
  }, [])

  const move = useCallback((si: number, bi: number) => {
    const book = latest.current.shelves[si]?.books[bi]
    if (!book) return
    setPulled(book.id)
    spines.current.get(book.id)?.focus()
  }, [])

  const onSpineKey = useCallback(
    (e: KeyboardEvent, si: number, bi: number) => {
      const { shelves, pulled, onOpen } = latest.current
      const vertical = (step: 1 | -1) => {
        for (let i = si + step; i >= 0 && i < shelves.length; i += step) {
          if (shelves[i].books.length) return move(i, Math.min(bi, shelves[i].books.length - 1))
        }
      }
      const actions: Record<string, (() => void) | null> = {
        ArrowRight: () => move(si, bi + 1),
        ArrowLeft: () => move(si, bi - 1),
        ArrowDown: () => vertical(1),
        ArrowUp: () => vertical(-1),
        Home: () => move(si, 0),
        End: () => move(si, shelves[si].books.length - 1),
        Enter: () => onOpen(shelves[si].books[bi]),
        Escape: pulled ? () => setPulled(null) : null,
      }
      const action = actions[e.key]
      if (!action) return
      e.preventDefault()
      action()
    },
    [move],
  )

  const onSpineClick = useCallback((si: number, bi: number) => {
    const { shelves, pulled, hover, onOpen } = latest.current
    const book = shelves[si].books[bi]
    if (hover || pulled === book.id) onOpen(book)
    else setPulled(book.id)
  }, [])

  const onSpineFocus = useCallback((si: number, bi: number) => setFocus([si, bi]), [])

  return (
    <div className="bs-case">
      {shelves.map((shelf, si) => {
        const label = shelfLabel(t, shelf.key)
        const headingId = `shelf-${shelf.key}`
        return (
          <section
            key={shelf.key}
            className="bs-shelf"
            aria-labelledby={headingId}
            ref={(el) => {
              if (el) sections.current.set(shelf.key, el)
            }}
          >
            <h2 className="bs-shelf__plaque" id={headingId}>
              {label} · {shelf.count}
            </h2>
            {!hover && pulledBook && pulledShelf?.key === shelf.key && (
              <button
                type="button"
                className="bs-caption"
                aria-label={labels.get(pulledBook.id)}
                style={{ "--x": `${captionX}px` } as CSSProperties}
                onClick={() => onOpen(pulledBook)}
              >
                <span className="bs-caption__title">{pulledBook.title}</span>
                {pulledBook.author && <span className="bs-caption__author">{pulledBook.author}</span>}
                <StatusMark text={statusLine(t, lng, primaryEdition(pulledBook))} formats={formatsOf(pulledBook)} />
              </button>
            )}
            <ul className="bs-shelf__row">
              {shelf.books.length === 0 && <li className="bs-shelf__empty">{t("shelf.empty")}</li>}
              {shelf.books.map((book, bi) => (
                <li key={book.id}>
                  <Spine
                    book={book}
                    si={si}
                    bi={bi}
                    pulled={pulled === book.id}
                    match={matches?.has(book.id) ?? false}
                    expandable={!hover}
                    tabbable={book.id === tabbable}
                    label={labels.get(book.id)!}
                    register={register}
                    onSpineClick={onSpineClick}
                    onSpineKey={onSpineKey}
                    onSpineFocus={onSpineFocus}
                  />
                </li>
              ))}
              {onMore && shelf.books.length < shelf.count && (
                <ShelfEnd key={shelf.books.length} shelfKey={shelf.key} horizontal onMore={onMore} />
              )}
            </ul>
            <div className="bs-shelf__plank" />
          </section>
        )
      })}
    </div>
  )
}

type SpineProps = {
  book: BookSummary
  si: number
  bi: number
  pulled: boolean
  match: boolean
  expandable: boolean
  tabbable: boolean
  label: string
  register: (id: string, el: HTMLButtonElement | null) => void
  onSpineClick: (si: number, bi: number) => void
  onSpineKey: (e: KeyboardEvent, si: number, bi: number) => void
  onSpineFocus: (si: number, bi: number) => void
}

const Spine = memo(function Spine({
  book,
  si,
  bi,
  pulled,
  match,
  expandable,
  tabbable,
  label,
  register,
  onSpineClick,
  onSpineKey,
  onSpineFocus,
}: SpineProps) {
  const { width, height, narrow } = spineSize(book)
  const className = [
    "bs-spine",
    `bs-cloth--${clothFor(book)}`,
    narrow && "bs-spine--narrow",
    pulled && "is-pulled",
    match && !pulled && "is-match",
  ]
    .filter(Boolean)
    .join(" ")
  return (
    <button
      ref={(el) => register(book.id, el)}
      type="button"
      className={className}
      lang={bookLang(book)}
      data-book={book.id}
      style={{ "--spine-w": `${width}px`, "--spine-h": `${height}px` } as CSSProperties}
      aria-label={label}
      aria-expanded={expandable ? pulled : undefined}
      tabIndex={tabbable ? 0 : -1}
      onClick={() => onSpineClick(si, bi)}
      onKeyDown={(e) => onSpineKey(e, si, bi)}
      onFocus={() => onSpineFocus(si, bi)}
    >
      <span className="bs-spine__text">
        <span className="bs-spine__title">{book.title}</span>
        {book.author && <span className="bs-spine__author">{book.author}</span>}
      </span>
      <span className="bs-spine__format">
        {formatsOf(book).map((f) => (
          <Ico key={f} name={f} />
        ))}
      </span>
    </button>
  )
})

export function BookcaseSkeleton() {
  const rows = [
    [32, 28, 38, 30, 34, 28, 40, 32],
    [30, 36, 28, 34, 30, 38],
    [34, 30, 28, 36, 32, 30, 28],
  ]
  return (
    <div className="bs-case" aria-busy="true">
      {rows.map((row, i) => (
        <div className="bs-shelf" key={i}>
          <ul className="bs-shelf__row" aria-hidden="true">
            {row.map((w, j) => (
              <li key={j}>
                <span
                  className="bs-spine bs-cloth--blank is-loading"
                  style={{ "--spine-w": `${w}px`, "--spine-h": `${136 + ((i * 3 + j * 5) % 7) * 8}px` } as CSSProperties}
                />
              </li>
            ))}
          </ul>
          <div className="bs-shelf__plank" />
        </div>
      ))}
    </div>
  )
}
