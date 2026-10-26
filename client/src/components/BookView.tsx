import { useEffect, useLayoutEffect, useRef, useState, type CSSProperties } from "react"
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
import type { ApiError } from "@/lib/api"
import type { BookDetail, BookSummary, Edition, Highlight, Note, Status } from "@/lib/types"
import { clothStyle } from "@/lib/cloth"
import { findOpener } from "@/lib/opener"
import { useMediaQuery } from "@/lib/useMediaQuery"
import { statusLine, statusWord, verbForm, errorMessage } from "@/lib/vocab"
import { Choices, Field, Ico } from "./ui"

type ViewProps = {
  bookId: string
  summary?: BookSummary
  disabled?: boolean
  onChanged: () => void
  closing?: boolean
  onClosed?: () => void
}

export function BookView({ bookId, summary, disabled, onChanged, closing, onClosed }: ViewProps) {
  const { t } = useTranslation()
  const reduced = useMediaQuery("(prefers-reduced-motion: reduce)")
  const [detail, setDetail] = useState<BookDetail | null>(null)
  const [error, setError] = useState(false)
  const [from, setFrom] = useState<CSSProperties | null>(null)
  const [opened, setOpened] = useState(reduced)
  const frame = useRef<HTMLDivElement>(null)

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
    return () => {
      live = false
    }
  }, [bookId])

  const shown = detail ?? summary
  const ready = !!(shown || error)

  useLayoutEffect(() => {
    const book = frame.current?.parentElement
    if (opened || from || !book) return
    const spine = findOpener(bookId)?.getBoundingClientRect()
    const r = book.getBoundingClientRect()
    const dx = spine ? spine.left + spine.width / 2 - (r.left + r.width / 2) : 0
    const dy = spine ? spine.top + spine.height / 2 - (r.top + r.height / 2) : 0
    setFrom({ "--from-x": `${Math.round(dx)}px`, "--from-y": `${Math.round(dy)}px` } as CSSProperties)
  }, [bookId, ready, opened, from])

  useLayoutEffect(() => {
    const book = frame.current?.parentElement
    if (!closing) return
    if (reduced || !book) return onClosed?.()
    const spine = findOpener(bookId)?.getBoundingClientRect()
    const r = book.getBoundingClientRect()
    const dx = spine ? spine.left + spine.width / 2 - (r.left + r.width / 2) : 0
    const dy = spine ? spine.top + spine.height / 2 - (r.top + r.height / 2) : 0
    setFrom({ "--from-x": `${Math.round(dx)}px`, "--from-y": `${Math.round(dy)}px` } as CSSProperties)
    const animation = getComputedStyle(book).animationName
    if (!animation || animation === "none") onClosed?.()
  }, [closing, reduced, bookId, onClosed])

  if (!ready) return <p className="bs-sr">{t("book.loading")}</p>

  const flying = !opened && from
  const className = ["bs-book", flying && !closing && "bs-fly", closing && "is-closing"].filter(Boolean).join(" ")
  return (
    <div
      className={className}
      style={from ?? undefined}
      onAnimationEnd={(e) => closing && e.target === e.currentTarget && onClosed?.()}
    >
      <div className="bs-book__frame" ref={frame}>
        <BookSpread
          book={detail ?? shown!}
          error={error}
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
        {(!opened || closing) && shown && (
          <div
            className={`bs-flap bs-cloth--${shown.cloth}`}
            style={clothStyle(shown)}
            aria-hidden="true"
            onAnimationEnd={(e) => e.target === e.currentTarget && setOpened(true)}
          >
            {shown.cover_url ? (
              <img className="bs-closed__jacket" src={shown.cover_url} alt="" />
            ) : (
              <div className="bs-closed__label">
                {shown.author && <span className="bs-closed__author">{shown.author}</span>}
                <span className="bs-closed__title">{shown.title}</span>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  )
}

type SpreadProps = {
  book: BookSummary | BookDetail
  error?: boolean
  disabled?: boolean
  onBook: (book: BookDetail) => void
  onReload: () => void
}

export function BookSpread({ book, error, disabled, onBook, onReload }: SpreadProps) {
  const { t } = useTranslation()
  const cloth = book.cloth
  const detail = "notes" in book ? book : null
  const title = useRef<HTMLHeadingElement>(null)
  const [editor, setEditor] = useState<string | null>(null)

  useEffect(() => {
    title.current?.focus({ preventScroll: true })
  }, [])

  let rest
  if (detail) {
    rest = (
      <>
        <Notes book={detail} disabled={disabled} onBook={onBook} />
        <Highlights book={detail} />
        <div className="bs-spread__foot">
          <MergeControl book={detail} disabled={disabled} onBook={onBook} onReload={onReload} />
        </div>
      </>
    )
  } else if (error) {
    rest = (
      <>
        <p className="bs-page__error">{t("book.loadError")}</p>
        <div>
          <button type="button" className="bs-btn bs-btn--quiet" onClick={onReload}>
            {t("book.retry")}
          </button>
        </div>
      </>
    )
  } else {
    rest = <p className="bs-sr">{t("book.loading")}</p>
  }

  return (
    <article className={`bs-spread bs-cloth--${cloth}`} style={clothStyle(book)} aria-labelledby="book-title">
      <section className="bs-page bs-page--left bs-title-page" aria-label={t("book.page", { n: 2 })}>
        {book.cover_url ? (
          <img className="bs-cover" src={book.cover_url} alt={t("book.cover")} />
        ) : (
          <div className={`bs-cover bs-cloth--${cloth}`} style={clothStyle(book)} role="img" aria-label={t("book.cover")}>
            {book.title}
          </div>
        )}
        {book.author && <p className="bs-book__author">{book.author}</p>}
        <h1 className="bs-book__title" id="book-title" tabIndex={-1} ref={title}>
          {book.title}
        </h1>
        <span className="bs-ornament" aria-hidden="true" />
        <ul className="bs-colophon">
          {book.editions.map((edition) => (
            <EditionLine
              key={edition.id}
              edition={edition}
              disabled={disabled}
              editing={editor === edition.id}
              onEdit={(open) => setEditor((cur) => (open ? edition.id : cur === edition.id ? null : cur))}
              onSaved={onReload}
            />
          ))}
        </ul>
        {detail && (
          <AddFormat
            book={detail}
            disabled={disabled}
            open={editor === "add"}
            onOpen={(open) => setEditor((cur) => (open ? "add" : cur === "add" ? null : cur))}
            onBook={onBook}
          />
        )}
        {book.bought_twice && <p className="bs-book__twice">{t("book.boughtTwice")}</p>}
        <p className="bs-page__folio" aria-hidden="true">
          2
        </p>
      </section>
      <section className="bs-page bs-page--right" aria-label={t("book.page", { n: 3 })}>
        <p className="bs-page__head">{book.title}</p>
        {rest}
        <p className="bs-page__folio" aria-hidden="true">
          3
        </p>
      </section>
    </article>
  )
}

type EditionLineProps = {
  edition: Edition
  disabled?: boolean
  editing: boolean
  onEdit: (open: boolean) => void
  onSaved: () => void
}

function EditionLine({ edition, disabled, editing, onEdit, onSaved }: EditionLineProps) {
  const { t, i18n } = useTranslation()
  const [status, setStatus] = useState<Status | null>(edition.status)
  const [error, setError] = useState(false)
  const shown = { ...edition, status }
  const where = [t(`format.${edition.format}`), edition.store && t(`store.${edition.store}`)].filter(Boolean).join(", ")
  const dateField = status === "done" ? "finished_at" : status === "in_progress" ? "started_at" : null
  const when = dateField ? (edition[dateField] ?? "").slice(0, 7) : ""

  const queue = useRef(Promise.resolve())
  const save = (next: Status, month?: string) => {
    const previous = status
    setStatus(next)
    setError(false)
    const field = next === "done" ? "finished_at" : next === "in_progress" ? "started_at" : null
    const body = { status: next, ...(field && month !== undefined ? { [field]: month && `${month}-01` } : {}) }
    queue.current = queue.current
      .then(() => updateEdition(edition.id, body))
      .then(
        () => {
          if (!field) onEdit(false)
          onSaved()
        },
        () => {
          setStatus(previous)
          setError(true)
        },
      )
  }

  return (
    <li className="bs-colophon__edition">
      <button
        type="button"
        className="bs-colophon__line"
        aria-expanded={editing}
        disabled={disabled}
        onClick={() => onEdit(!editing)}
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
          onChange={(next) => save(next)}
          options={(["want", "owned", "in_progress", "done"] as Status[]).map((s) => ({
            value: s,
            label: statusWord(t, s, edition.format),
          }))}
        />
      )}
      {editing && status && dateField && (
        <Field
          hand
          type="month"
          label={t("entry.when")}
          defaultValue={when}
          key={`${status}:${when}`}
          disabled={disabled}
          onBlur={(e) => e.target.value !== when && save(status, e.target.value)}
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
  const [failed, setFailed] = useState(false)
  if (book.highlights_count === 0) return null
  const rest = book.highlights_count - items.length

  const more = async () => {
    setBusy(true)
    setFailed(false)
    try {
      const { highlights } = await getHighlights(book.id, items.length)
      setItems([...items, ...highlights])
    } catch {
      setFailed(true)
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
      {failed && <p className="bs-field__error">{t("book.highlightsError")}</p>}
      {rest > 0 && (
        <div>
          <button type="button" className="bs-btn bs-btn--quiet" aria-busy={busy} disabled={busy} onClick={more}>
            {failed ? t("book.retry") : t("book.moreHighlights", { count: rest })}
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
  const undo = (id: string) => unmerge(id).then(onReload, (e: ApiError) => (e.status === 404 ? onReload() : fail(e)))

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
            onClick={() => undo(m.id)}
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

type AddFormatProps = {
  book: BookDetail
  disabled?: boolean
  open: boolean
  onOpen: (open: boolean) => void
  onBook: (b: BookDetail) => void
}

function AddFormat({ book, disabled, open, onOpen, onBook }: AddFormatProps) {
  const { t } = useTranslation()
  const has = new Set(book.editions.map((e) => verbForm(e.format)))
  const format = (["audio", "ebook"] as const).find((f) => !has.has(f))
  const [status, setStatus] = useState<Status>("done")
  const [error, setError] = useState<string | null>(null)

  if (!format) return null
  if (!open) {
    return (
      <button type="button" className="bs-btn bs-btn--quiet bs-btn--sm" disabled={disabled} onClick={() => onOpen(true)}>
        {t(`book.addFormat.${format}`)}
      </button>
    )
  }

  const save = async () => {
    try {
      const { book: next } = await addEdition(book.id, { format, status })
      onOpen(false)
      onBook(next)
    } catch (e) {
      setError(errorMessage(t, e))
    }
  }

  return (
    <div className="bs-merge">
      <Choices
        legend={t(`book.addFormat.${format}`)}
        value={status}
        onChange={setStatus}
        options={(["want", "owned", "in_progress", "done"] as Status[]).map((s) => ({ value: s, label: statusWord(t, s, format) }))}
      />
      {error && <span className="bs-field__error">{error}</span>}
      <div className="bs-note-edit__actions">
        <button type="button" className="bs-btn bs-btn--quiet bs-btn--sm" onClick={() => onOpen(false)}>
          {t("common.cancel")}
        </button>
        <button type="button" className="bs-btn bs-btn--secondary bs-btn--sm" onClick={save}>
          {t("entry.save")}
        </button>
      </div>
    </div>
  )
}
