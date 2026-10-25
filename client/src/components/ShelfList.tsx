import type { KeyboardEvent } from "react"
import { useTranslation } from "react-i18next"
import { isYear, shelfLabel } from "@/lib/arrange"
import { clothFor } from "@/lib/cloth"
import type { BookSummary, Shelf } from "@/lib/types"
import { formatsOf, primaryEdition, statusLine } from "@/lib/vocab"
import { StatusMark } from "./ui"

export function ShelfList({ shelves, onOpen }: { shelves: Shelf[]; onOpen: (book: BookSummary) => void }) {
  const { t, i18n } = useTranslation()

  const onKeyDown = (e: KeyboardEvent<HTMLDivElement>) => {
    if (e.key !== "ArrowDown" && e.key !== "ArrowUp") return
    const rows = [...e.currentTarget.querySelectorAll<HTMLButtonElement>(".bs-row")]
    const i = rows.indexOf(document.activeElement as HTMLButtonElement)
    const next = rows[i + (e.key === "ArrowDown" ? 1 : -1)]
    if (!next) return
    e.preventDefault()
    next.focus()
  }

  return (
    <div onKeyDown={onKeyDown}>
      {shelves
        .filter((s) => s.books.length > 0)
        .map((shelf) => (
          <section className="bs-list" key={shelf.key} aria-labelledby={`list-${shelf.key}`}>
            <h2 className="bs-list__head" id={`list-${shelf.key}`}>
              {shelfLabel(t, shelf.key)} · {shelf.count}
            </h2>
            <ul>
              {shelf.books.map((book) => {
                const edition = primaryEdition(book)
                return (
                  <li key={book.id}>
                    <button type="button" className="bs-row" onClick={() => onOpen(book)}>
                      <span className={`bs-row__spine bs-cloth--${clothFor(book)}`} aria-hidden="true" />
                      <span className="bs-row__body">
                        <span className="bs-row__title">{book.title}</span>
                        {book.author && <span className="bs-row__author">{book.author}</span>}
                      </span>
                      <StatusMark
                        text={statusLine(t, i18n.language, edition, { monthOnly: isYear(shelf.key) })}
                        formats={formatsOf(book)}
                        strong={shelf.key === "now"}
                      />
                    </button>
                  </li>
                )
              })}
            </ul>
          </section>
        ))}
    </div>
  )
}
