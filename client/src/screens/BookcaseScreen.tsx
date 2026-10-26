import { useCallback, useEffect, useMemo, useState } from "react"
import { useTranslation } from "react-i18next"
import { useLocation, useNavigate, useSearchParams } from "react-router-dom"
import { getSources, updateEdition } from "@/api"
import { Bookcase, BookcaseSkeleton } from "@/components/Bookcase"
import { BookView } from "@/components/BookView"
import { EmptyCase } from "@/components/EmptyCase"
import { EntryForm, type EntryDraft } from "@/components/EntryForm"
import { Overlay } from "@/components/Overlay"
import { SearchField } from "@/components/SearchField"
import { ShelfList } from "@/components/ShelfList"
import { SourceBanner } from "@/components/SourceBanner"
import { Choices, Ico } from "@/components/ui"
import { arrangeShelves, isEmptyCase, movedBook, shelfStatus } from "@/lib/arrange"
import { pickBanner, type BannerEvent } from "@/lib/banner"
import { readPref, writePref } from "@/lib/cache"
import { findOpener } from "@/lib/opener"
import { useShelf } from "@/lib/shelf"
import type { Banner, BookSummary, ShelfKey } from "@/lib/types"
import { useOnline } from "@/lib/useOnline"

type View = "case" | "list"

const FIELD = 'input, textarea, select, [contenteditable]:not([contenteditable="false"])'

function readDismissed() {
  try {
    return new Set<string>(JSON.parse(readPref("dismissed") ?? "[]"))
  } catch {
    return new Set<string>()
  }
}

export function BookcaseScreen() {
  const { t } = useTranslation()
  const shelf = useShelf()
  const online = useOnline()
  const navigate = useNavigate()
  const location = useLocation()
  const [params] = useSearchParams()
  const openId = params.get("book")

  const [view, setView] = useState<View>(() => (readPref("view") === "list" ? "list" : "case"))
  const [matches, setMatches] = useState<Set<string>>(new Set())
  const [entry, setEntry] = useState<EntryDraft | null>(null)
  const [serverBanner, setServerBanner] = useState<Banner | null>(null)
  const [dismissed, setDismissed] = useState(readDismissed)

  const offline = !online || shelf.error === "network"

  useEffect(() => {
    getSources()
      .then((r) => setServerBanner(r.banner))
      .catch(() => {})
  }, [])

  const open = useCallback(
    (book: BookSummary) => navigate({ search: `?book=${book.id}` }, { state: { opened: true } }),
    [navigate],
  )
  const close = useCallback(() => {
    if ((location.state as { opened?: boolean } | null)?.opened) navigate(-1)
    else navigate({ search: "" }, { replace: true })
  }, [location.state, navigate])

  const { reload, place } = shelf
  const move = useCallback(
    (book: BookSummary, to: ShelfKey) => {
      const changes = book.editions.map((e) => shelfStatus(e, to))
      place(movedBook(book, to, changes))
      Promise.all(book.editions.map((e, i) => updateEdition(e.id, changes[i]))).catch(reload)
    },
    [reload, place],
  )

  const [bookId, setBookId] = useState(openId)
  if (openId && openId !== bookId) setBookId(openId)

  const shelves = useMemo(() => (shelf.shelves ? arrangeShelves(shelf.shelves) : null), [shelf.shelves])
  const summary = shelves?.flatMap((s) => s.books).find((b) => b.id === bookId)

  const banner = pickBanner([offline ? { kind: "offline" } : null, serverBanner], dismissed)

  const dismiss = (event: BannerEvent) => {
    if (event.kind === "offline" || !event.dismissible) return
    const next = new Set(dismissed).add(event.key)
    setDismissed(next)
    writePref("dismissed", JSON.stringify([...next]))
  }

  const changeView = (next: View) => {
    setView(next)
    writePref("view", next)
  }

  let body
  if (!shelves && shelf.error) {
    body = (
      <p className="bs-retry">
        {t("shelf.loadError")}
        <button type="button" className="bs-btn bs-btn--quiet" onClick={shelf.reload}>
          {t("book.retry")}
        </button>
      </p>
    )
  } else if (!shelves) {
    body = <BookcaseSkeleton />
  } else if (isEmptyCase(shelves)) {
    body = (
      <EmptyCase
        disabled={offline}
        onAdd={() => setEntry({})}
      />
    )
  } else if (view === "list") {
    body = <ShelfList shelves={shelves} onOpen={open} onMore={shelf.loadMore} />
  } else {
    body = <Bookcase shelves={shelves} matches={matches} onOpen={open} onMore={shelf.loadMore} onMove={offline ? undefined : move} />
  }

  const hasBooks = shelves && !isEmptyCase(shelves)

  return (
    <div className="bs-shelfscreen">
      <div className="bs-shelfscreen__case">
        <h1 className="bs-sr">{t("tabs.shelf")}</h1>
        <SearchField disabled={offline} onMatches={setMatches} onWrite={setEntry} onAdded={shelf.reload} />
        {banner && <SourceBanner event={banner} onDismiss={() => dismiss(banner)} />}
        {hasBooks && (
          <div className="bs-shelfscreen__tools">
            <Choices
              legend={t("shelf.view")}
              hideLegend
              value={view}
              onChange={changeView}
              options={[
                { value: "case", label: t("shelf.viewCase") },
                { value: "list", label: t("shelf.viewList") },
              ]}
            />
            <button type="button" className="bs-btn bs-btn--secondary" disabled={offline} onClick={() => setEntry({})}>
              <Ico name="pen" />
              {t("shelf.addBook")}
            </button>
          </div>
        )}
        {body}
      </div>
      <Overlay
        open={!!openId}
        label={summary?.title ?? t("book.label")}
        className="bs-dialog--book"
        onClose={close}
        onEscapeKeyDown={(e) => {
          if ((e.target as Element).closest?.(FIELD)) e.preventDefault()
        }}
        onCloseAutoFocus={(e) => {
          e.preventDefault()
          if (bookId) findOpener(bookId)?.focus()
        }}
      >
        {bookId && <BookView key={bookId} bookId={bookId} summary={summary} disabled={offline} onChanged={shelf.reload} />}
      </Overlay>
      <Overlay open={!!entry} label={t("entry.title")} onClose={() => setEntry(null)}>
        {entry && (
          <EntryForm
            draft={entry}
            disabled={offline}
            onCancel={() => setEntry(null)}
            onSaved={() => {
              setEntry(null)
              shelf.reload()
            }}
          />
        )}
      </Overlay>
    </div>
  )
}
