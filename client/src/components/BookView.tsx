import { useEffect, useState } from "react"
import { useTranslation } from "react-i18next"
import {
  addEdition,
  addNote,
  deleteNote,
  getBook,
  getHighlights,
  mergeBooks,
  search,
  unmerge,
  updateEdition,
  updateNote,
} from "@/api"
import { clothFor } from "@/lib/cloth"
import type { BookDetail, BookSummary, Edition, Highlight, Note, Status } from "@/lib/types"
import { useMediaQuery } from "@/lib/useMediaQuery"
import { formatsOf, statusLine, statusWord, verbForm, errorMessage } from "@/lib/vocab"
import { Choices, Ico } from "./ui"

type ViewProps = {
  bookId: string
  summary?: BookSummary
  disabled?: boolean
  onChanged: () => void
}

export function BookView({ bookId, summary, disabled, onChanged }: ViewProps) {
  const { t } = useTranslation()
  const reduced = useMediaQuery("(prefers-reduced-motion: reduce)")
  const [detail, setDetail] = useState<BookDetail | null>(null)
  const [error, setError] = useState(false)
  const [taken, setTaken] = useState(reduced)

  const load = () => {
    setError(false)
    getBook(bookId)
      .then(({ book }) => setDetail(book))
      .catch(() => setError(true))
  }

  useEffect(() => {
    let live = true
    getBook(bookId)
      .then(({ book }) => live && setDetail(book))
      .catch(() => live && setError(true))
    const timer = window.setTimeout(() => live && setTaken(true), reduced ? 0 : 260)
    return () => {
      live = false
      window.clearTimeout(timer)
    }
  }, [bookId, reduced])

  const shown = detail ?? summary
  if (!taken || (!detail && !error)) {
    return shown ? <BookCover book={shown} animate={!reduced} /> : <p className="bs-sr">{t("book.loading")}</p>
  }

  if (!detail) {
    return (
      <div className="bs-book">
        <article className={`bs-spread bs-cloth--${shown ? clothFor(shown) : "blank"}`}>
          <section className="bs-page bs-page--left bs-title-page">
            {shown && <h1 className="bs-book__title">{shown.title}</h1>}
          </section>
          <section className="bs-page bs-page--right">
            <p className="bs-page__error">{t("book.loadError")}</p>
            <div>
              <button type="button" className="bs-btn bs-btn--quiet" onClick={load}>
                {t("book.retry")}
              </button>
            </div>
          </section>
        </article>
      </div>
    )
  }

  return (
    <BookSpread
      book={detail}
      animate={!reduced}
      disabled={disabled}
      onBook={(book) => {
        setDetail(book)
        onChanged()
      }}
      onReload={() => {
        load()
        onChanged()
      }}
    />
  )
}

export function BookCover({ book, animate }: { book: BookSummary; animate?: boolean }) {
  const { t } = useTranslation()
  const formats = formatsOf(book)
  return (
    <div
      className={`bs-closed bs-cloth--${clothFor(book)}${animate ? " is-taking" : ""}`}
      role="img"
      aria-label={`${book.title}${book.author ? `, ${book.author}` : ""}. ${formats.map((f) => t(`format.${f}`)).join(", ")}`}
    >
      {book.cover_url ? (
        <img className="bs-closed__jacket" src={book.cover_url} alt="" />
      ) : (
        <div className="bs-closed__label">
          {book.author && <span className="bs-closed__author">{book.author}</span>}
          <span className="bs-closed__title">{book.title}</span>
        </div>
      )}
      <span className="bs-closed__format">
        {formats.map((f) => (
          <Ico key={f} name={f} />
        ))}
      </span>
    </div>
  )
}

type SpreadProps = {
  book: BookDetail
  animate?: boolean
  disabled?: boolean
  onBook: (book: BookDetail) => void
  onReload: () => void
}

export function BookSpread({ book, animate, disabled, onBook, onReload }: SpreadProps) {
  const { t } = useTranslation()
  const cloth = clothFor(book)

  return (
    <div className="bs-book">
      <article className={`bs-spread bs-cloth--${cloth}${animate ? " is-opening" : ""}`} aria-labelledby="book-title">
        <section className="bs-page bs-page--left bs-title-page" aria-label={t("book.page", { n: 2 })}>
          {book.cover_url ? (
            <img className="bs-cover" src={book.cover_url} alt={t("book.cover")} />
          ) : (
            <div className={`bs-cover bs-cloth--${cloth}`} role="img" aria-label={t("book.cover")}>
              {book.title}
            </div>
          )}
          {book.author && <p className="bs-book__author">{book.author}</p>}
          <h1 className="bs-book__title" id="book-title">
            {book.title}
          </h1>
          <span className="bs-ornament" aria-hidden="true" />
          <ul className="bs-colophon">
            {book.editions.map((edition) => (
              <EditionLine key={edition.id} edition={edition} disabled={disabled} onSaved={onReload} />
            ))}
          </ul>
          <AddFormat book={book} disabled={disabled} onBook={onBook} />
          {book.bought_twice && <p className="bs-book__twice">{t("book.boughtTwice")}</p>}
          <p className="bs-page__folio" aria-hidden="true">
            2
          </p>
        </section>
        <section className="bs-page bs-page--right" aria-label={t("book.page", { n: 3 })}>
          <p className="bs-page__head">{book.title}</p>
          <Notes book={book} disabled={disabled} onBook={onBook} />
          <Highlights book={book} />
          <div className="bs-spread__foot">
            <MergeControl book={book} disabled={disabled} onBook={onBook} onReload={onReload} />
          </div>
          <p className="bs-page__folio" aria-hidden="true">
            3
          </p>
        </section>
      </article>
    </div>
  )
}

function EditionLine({ edition, disabled, onSaved }: { edition: Edition; disabled?: boolean; onSaved: () => void }) {
  const { t, i18n } = useTranslation()
  const [editing, setEditing] = useState(false)
  const [status, setStatus] = useState<Status | null>(edition.status)
  const [error, setError] = useState(false)
  const shown = { ...edition, status }
  const where = [t(`format.${edition.format}`), edition.store && t(`store.${edition.store}`)].filter(Boolean).join(", ")

  const change = async (next: Status) => {
    const previous = status
    setStatus(next)
    setError(false)
    try {
      await updateEdition(edition.id, { status: next })
      setEditing(false)
      onSaved()
    } catch {
      setStatus(previous)
      setError(true)
    }
  }

  return (
    <li className="bs-colophon__edition">
      <button
        type="button"
        className="bs-colophon__line"
        aria-expanded={editing}
        disabled={disabled}
        onClick={() => setEditing(!editing)}
      >
        <Ico name={verbForm(edition.format)} />
        <span>
          {where}. {statusLine(t, i18n.language, shown) || t("book.noStatus")}
        </span>
      </button>
      {editing && (
        <Choices
          legend={t("entry.status")}
          hideLegend
          value={status ?? ("" as Status)}
          onChange={change}
          options={(["want", "owned", "in_progress", "done"] as Status[]).map((s) => ({
            value: s,
            label: statusWord(t, s, edition.format),
          }))}
        />
      )}
      {error && <span className="bs-field__error">{t("book.statusError")}</span>}
    </li>
  )
}

function Notes({ book, disabled, onBook }: { book: BookDetail; disabled?: boolean; onBook: (b: BookDetail) => void }) {
  const { t } = useTranslation()
  const [editing, setEditing] = useState<string | "new" | null>(null)
  const [draft, setDraft] = useState("")
  const [error, setError] = useState<string | null>(null)

  const setNotes = (notes: Note[]) => onBook({ ...book, notes })
  const start = (id: string | "new", body = "") => {
    setEditing(id)
    setDraft(body)
    setError(null)
  }

  const save = async () => {
    const body = draft.trim()
    if (!body) return setError(t("errors.blank"))
    try {
      if (editing === "new") {
        const { note } = await addNote(book.id, body)
        setNotes([...book.notes, note])
      } else if (editing) {
        const { note } = await updateNote(editing, body)
        setNotes(book.notes.map((n) => (n.id === note.id ? note : n)))
      }
      setEditing(null)
    } catch (e) {
      setError(errorMessage(t, e))
    }
  }

  const remove = async (id: string) => {
    try {
      await deleteNote(id)
      setNotes(book.notes.filter((n) => n.id !== id))
      setEditing(null)
    } catch (e) {
      setError(errorMessage(t, e))
    }
  }

  const editor = (
    <div className="bs-note-edit">
      <label className="bs-sr" htmlFor="note-draft">
        {t("book.note")}
      </label>
      <textarea
        id="note-draft"
        className="bs-note-edit__input"
        value={draft}
        autoFocus
        aria-invalid={error ? true : undefined}
        aria-describedby={error ? "note-error" : undefined}
        onChange={(e) => setDraft(e.target.value)}
      />
      {error && (
        <span className="bs-field__error" id="note-error">
          {error}
        </span>
      )}
      <div className="bs-note-edit__actions">
        {editing !== "new" && editing && (
          <button type="button" className="bs-btn bs-btn--quiet bs-btn--sm" onClick={() => remove(editing)}>
            {t("book.deleteNote")}
          </button>
        )}
        <button type="button" className="bs-btn bs-btn--quiet bs-btn--sm" onClick={() => setEditing(null)}>
          {t("common.cancel")}
        </button>
        <button type="button" className="bs-btn bs-btn--secondary bs-btn--sm" onClick={save}>
          {t("book.saveNote")}
        </button>
      </div>
    </div>
  )

  return (
    <>
      <h2 className="bs-page__h">{t("book.notes")}</h2>
      {book.notes.map((note) =>
        editing === note.id ? (
          <div key={note.id}>{editor}</div>
        ) : (
          <button
            key={note.id}
            type="button"
            className="bs-note bs-note--button"
            disabled={disabled}
            aria-label={`${t("book.editNote")}: ${note.body}`}
            onClick={() => start(note.id, note.body)}
          >
            {note.body}
          </button>
        ),
      )}
      {editing === "new" ? (
        editor
      ) : (
        <div>
          <button type="button" className="bs-btn bs-btn--quiet" disabled={disabled} onClick={() => start("new")}>
            <Ico name="pen" />
            {t("book.addNote")}
          </button>
        </div>
      )}
    </>
  )
}

function Highlights({ book }: { book: BookDetail }) {
  const { t } = useTranslation()
  const [items, setItems] = useState<Highlight[]>(book.highlights)
  const [busy, setBusy] = useState(false)
  if (book.highlights_count === 0) return null
  const rest = book.highlights_count - items.length

  const more = async () => {
    setBusy(true)
    try {
      const { highlights } = await getHighlights(book.id, items.length)
      setItems([...items, ...highlights])
    } finally {
      setBusy(false)
    }
  }

  return (
    <>
      <h2 className="bs-page__h">{t("book.highlights")}</h2>
      <ul className="bs-highlights">
        {items.map((h) => (
          <li key={h.id}>
            <p className="bs-highlight">
              <mark>{h.text}</mark>
            </p>
          </li>
        ))}
      </ul>
      {rest > 0 && (
        <div>
          <button type="button" className="bs-btn bs-btn--quiet" aria-busy={busy} onClick={more}>
            {t("book.moreHighlights", { count: rest })}
          </button>
        </div>
      )}
    </>
  )
}

function MergeControl({
  book,
  disabled,
  onBook,
  onReload,
}: {
  book: BookDetail
  disabled?: boolean
  onBook: (b: BookDetail) => void
  onReload: () => void
}) {
  const { t } = useTranslation()
  const [open, setOpen] = useState(false)
  const [query, setQuery] = useState("")
  const [results, setResults] = useState<BookSummary[]>([])
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open || query.trim().length < 2) return
    const timer = window.setTimeout(() => {
      search(query.trim())
        .then((r) => setResults(r.books.filter((b) => b.id !== book.id)))
        .catch(() => setResults([]))
    }, 250)
    return () => window.clearTimeout(timer)
  }, [open, query, book.id])

  const fail = (e: unknown) => setError(errorMessage(t, e))

  const merges = book.merges ?? []
  if (merges.length > 0) {
    return (
      <div className="bs-merge">
        {merges.map((m) => (
          <button
            key={m.id}
            type="button"
            className="bs-btn bs-btn--quiet bs-btn--sm"
            disabled={disabled}
            onClick={() => unmerge(m.id).then(onReload, fail)}
          >
            {merges.length === 1 ? t("book.unmerge") : t("book.unmergeOne", { title: m.title })}
          </button>
        ))}
        {error && <span className="bs-field__error">{error}</span>}
      </div>
    )
  }

  if (!open) {
    return (
      <button type="button" className="bs-btn bs-btn--quiet bs-btn--sm" disabled={disabled} onClick={() => setOpen(true)}>
        {t("book.merge")}
      </button>
    )
  }

  return (
    <div className="bs-merge">
      <label className="bs-field__label" htmlFor="merge-q">
        {t("book.mergeWith")}
      </label>
      <input
        id="merge-q"
        className="bs-field__input bs-field__input--plain"
        type="search"
        value={query}
        autoFocus
        onChange={(e) => setQuery(e.target.value)}
      />
      <ul className="bs-merge__results">
        {results.map((other) => (
          <li key={other.id}>
            <button
              type="button"
              className="bs-btn bs-btn--quiet bs-btn--sm"
              onClick={() => mergeBooks(book.id, other.id).then(({ book: merged }) => onBook(merged), fail)}
            >
              {other.title}
              {other.author ? `, ${other.author}` : ""}
            </button>
          </li>
        ))}
      </ul>
      {error && <span className="bs-field__error">{error}</span>}
      <button type="button" className="bs-btn bs-btn--quiet bs-btn--sm" onClick={() => setOpen(false)}>
        {t("common.cancel")}
      </button>
    </div>
  )
}

function AddFormat({ book, disabled, onBook }: { book: BookDetail; disabled?: boolean; onBook: (b: BookDetail) => void }) {
  const { t } = useTranslation()
  const has = new Set(book.editions.map((e) => verbForm(e.format)))
  const [open, setOpen] = useState(false)
  const [format, setFormat] = useState<"audio" | "ebook">(has.has("audio") ? "ebook" : "audio")
  const [status, setStatus] = useState<Status>("done")
  const [error, setError] = useState<string | null>(null)

  if (!open) {
    return (
      <button type="button" className="bs-btn bs-btn--quiet bs-btn--sm" disabled={disabled} onClick={() => setOpen(true)}>
        {t("book.addFormat")}
      </button>
    )
  }

  const save = async () => {
    try {
      const { book: next } = await addEdition(book.id, { format, status })
      setOpen(false)
      onBook(next)
    } catch (e) {
      setError(errorMessage(t, e))
    }
  }

  return (
    <div className="bs-merge">
      <Choices
        legend={t("entry.format")}
        value={format}
        onChange={setFormat}
        options={[
          { value: "audio", label: t("format.audio"), icon: "audio" },
          { value: "ebook", label: t("format.ebook"), icon: "ebook" },
        ]}
      />
      <Choices
        legend={t("entry.status")}
        value={status}
        onChange={setStatus}
        options={(["want", "owned", "in_progress", "done"] as Status[]).map((s) => ({ value: s, label: statusWord(t, s, format) }))}
      />
      {error && <span className="bs-field__error">{error}</span>}
      <div className="bs-note-edit__actions">
        <button type="button" className="bs-btn bs-btn--quiet bs-btn--sm" onClick={() => setOpen(false)}>
          {t("common.cancel")}
        </button>
        <button type="button" className="bs-btn bs-btn--secondary bs-btn--sm" onClick={save}>
          {t("entry.save")}
        </button>
      </div>
    </div>
  )
}
