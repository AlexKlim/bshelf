import { useEffect, useRef, useState, type CSSProperties, type KeyboardEvent } from "react"
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

export function Bookcase({ shelves, matches, onOpen, onMore }: Props) {
  const { t, i18n } = useTranslation()
  const hover = !useMediaQuery("(pointer: coarse)")
  const [pulled, setPulled] = useState<string | null>(null)
  const [focus, setFocus] = useState<[number, number] | null>(null)
  const [captionX, setCaptionX] = useState(0)
  const spines = useRef(new Map<string, HTMLButtonElement>())
  const sections = useRef(new Map<string, HTMLElement>())

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

  const spineLabel = (book: BookSummary) =>
    `${book.title}${book.author ? `, ${book.author}` : ""}. ${statusLine(t, i18n.language, primaryEdition(book), { separator: ", " })}`

  const move = (si: number, bi: number) => {
    const book = shelves[si]?.books[bi]
    if (!book) return
    setFocus([si, bi])
    setPulled(book.id)
    spines.current.get(book.id)?.focus()
  }

  const nextShelf = (from: number, step: 1 | -1) => {
    for (let i = from + step; i >= 0 && i < shelves.length; i += step) if (shelves[i].books.length) return i
    return -1
  }

  const onKey = (e: KeyboardEvent, si: number, bi: number, book: BookSummary) => {
    const vertical = (step: 1 | -1) => {
      const target = nextShelf(si, step)
      if (target >= 0) move(target, Math.min(bi, shelves[target].books.length - 1))
    }
    const actions: Record<string, () => void> = {
      ArrowRight: () => move(si, bi + 1),
      ArrowLeft: () => move(si, bi - 1),
      ArrowDown: () => vertical(1),
      ArrowUp: () => vertical(-1),
      Home: () => move(si, 0),
      End: () => move(si, shelves[si].books.length - 1),
      Enter: () => onOpen(book),
      Escape: () => setPulled(null),
    }
    const action = actions[e.key]
    if (!action) return
    e.preventDefault()
    action()
  }

  const onClick = (si: number, bi: number, book: BookSummary) => {
    setFocus([si, bi])
    if (hover || pulled === book.id) onOpen(book)
    else setPulled(book.id)
  }

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
                aria-label={spineLabel(pulledBook)}
                style={{ "--x": `${captionX}px` } as CSSProperties}
                onClick={() => onOpen(pulledBook)}
              >
                <span className="bs-caption__title">{pulledBook.title}</span>
                {pulledBook.author && <span className="bs-caption__author">{pulledBook.author}</span>}
                <StatusMark
                  text={statusLine(t, i18n.language, primaryEdition(pulledBook))}
                  formats={formatsOf(pulledBook)}
                />
              </button>
            )}
            <ul className="bs-shelf__row">
              {shelf.books.length === 0 && <li className="bs-shelf__empty">{t("shelf.empty")}</li>}
              {shelf.books.map((book, bi) => (
                <li key={book.id}>
                  <Spine
                    book={book}
                    pulled={pulled === book.id}
                    match={matches?.has(book.id) ?? false}
                    expandable={!hover}
                    tabIndex={book.id === tabbable ? 0 : -1}
                    label={spineLabel(book)}
                    buttonRef={(el) => {
                      if (el) spines.current.set(book.id, el)
                      else spines.current.delete(book.id)
                    }}
                    onClick={() => onClick(si, bi, book)}
                    onKeyDown={(e) => onKey(e, si, bi, book)}
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
  pulled: boolean
  match: boolean
  expandable: boolean
  tabIndex: number
  label: string
  buttonRef: (el: HTMLButtonElement | null) => void
  onClick: () => void
  onKeyDown: (e: KeyboardEvent) => void
}

function Spine({ book, pulled, match, expandable, tabIndex, label, buttonRef, onClick, onKeyDown }: SpineProps) {
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
      ref={buttonRef}
      type="button"
      className={className}
      lang={bookLang(book)}
      style={{ "--spine-w": `${width}px`, "--spine-h": `${height}px` } as CSSProperties}
      aria-label={label}
      aria-expanded={expandable ? pulled : undefined}
      tabIndex={tabIndex}
      onClick={onClick}
      onKeyDown={onKeyDown}
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
}

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
