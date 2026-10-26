import { useEffect, useState, type ChangeEvent } from "react"
import { useTranslation } from "react-i18next"
import { Link, useNavigate } from "react-router-dom"
import { dismissDuplicate, getDuplicates, getSources, mergeBooks, unmerge } from "@/api"
import { notOfferedYet, requestKindleExport, uploadKindleExport, type SyncResult } from "@/api/pending"
import { Ico } from "@/components/ui"
import type { ApiError } from "@/lib/api"
import { useShelf } from "@/lib/shelf"
import { errorMessage, isActive, syncResult } from "@/lib/vocab"
import type { Duplicate, Source } from "@/lib/types"
import { useOnline } from "@/lib/useOnline"

function ago(iso: string, lng: string) {
  const days = Math.round((Date.parse(iso) - Date.now()) / 86_400_000)
  const rtf = new Intl.RelativeTimeFormat(lng, { numeric: "auto" })
  if (Math.abs(days) < 1) {
    const hours = Math.round((Date.parse(iso) - Date.now()) / 3_600_000)
    return rtf.format(hours, "hour")
  }
  return rtf.format(days, "day")
}

export function SourcesScreen() {
  const { t } = useTranslation()
  const [sources, setSources] = useState<Source[] | null>(null)
  const [error, setError] = useState(false)

  useEffect(() => {
    getSources().then(
      (r) => setSources(r.sources),
      () => setError(true),
    )
  }, [])

  return (
    <div className="bs-screen bs-screen--sheet">
      <h1 className="bs-screen__title">{t("tabs.sources")}</h1>
      {error && <p className="bs-source__meta bs-source__meta--error">{t("sources.loadError")}</p>}
      {sources?.map((s) => <SourceRow key={s.kind} source={s} onChange={(next) => setSources(sources.map((x) => (x.kind === next.kind ? next : x)))} />)}
      <Duplicates />
    </div>
  )
}

function SourceRow({ source, onChange }: { source: Source; onChange: (s: Source) => void }) {
  const { t, i18n } = useTranslation()
  const navigate = useNavigate()
  const online = useOnline()
  const { reload } = useShelf()
  const [busy, setBusy] = useState(false)
  const [result, setResult] = useState<SyncResult | null>(null)
  const [error, setError] = useState<string | null>(null)
  const lng = i18n.language

  let meta = t("sources.never")
  if (source.last_sync_at) {
    meta = [t("sources.lastSync", { when: ago(source.last_sync_at, lng) }), source.books_count > 0 && t("count.books", { count: source.books_count })]
      .filter(Boolean)
      .join(" · ")
  }
  if (source.status === "requested" && source.requested_at) meta = t("sources.exportRequested", { when: ago(source.requested_at, lng) })
  if (source.status === "ready") meta = t("sources.exportReady")
  const session = source.session
  if (session?.status === "done" && session.result) meta = syncResult(t, session.result)
  if (session && isActive(session.status)) meta = t("sources.collecting")
  if (session?.status === "interrupted" && session.interruption !== "aborted") meta = t("sources.interrupted")
  if (result) meta = syncResult(t, result)
  const failed = error ?? (source.status === "error" || source.status === "needs_login" ? t(`sourceErrors.${source.error ?? source.status}`, { defaultValue: t("sourceErrors.generic") }) : null)

  const upload = async (e: ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    setBusy(true)
    setError(null)
    try {
      setResult(await uploadKindleExport(file))
      onChange({ ...source, status: "ok", last_sync_at: new Date().toISOString() })
      reload()
    } catch (err) {
      setError(notOfferedYet(err) ? t("sources.notAvailableYet") : errorMessage(t, err))
    } finally {
      setBusy(false)
    }
  }

  let action
  if (source.kind === "litres") {
    action = (
      <button type="button" className="bs-btn bs-btn--secondary" disabled={!online} onClick={() => navigate("/sources/litres")}>
        {t("sources.litresAction")}
      </button>
    )
  } else if (source.kind === "kindle_browser") {
    action = (
      <button type="button" className="bs-btn bs-btn--secondary" disabled={!online} onClick={() => navigate("/sources/kindle")}>
        {t("sources.kindleAction")}
      </button>
    )
  } else if (source.status === "requested") {
    action = (
      <button type="button" className="bs-btn bs-btn--secondary" disabled>
        {t("sources.waitingArchive")}
      </button>
    )
  } else if (source.status === "never") {
    action = (
      <button type="button" className="bs-btn bs-btn--secondary" disabled={!online} onClick={() => navigate("/sources/kindle-export")}>
        {t("sources.requestExport")}
      </button>
    )
  } else {
    action = (
      <label className={`bs-btn bs-btn--secondary${!online ? " is-disabled" : ""}`} aria-busy={busy}>
        <input type="file" accept=".zip,application/zip" className="bs-sr" disabled={!online || busy} onChange={upload} />
        {busy ? t("sources.importing") : t("sources.uploadArchive")}
      </label>
    )
  }

  return (
    <div className="bs-source">
      <div className="bs-source__body">
        <span className="bs-source__name">{t(`sources.name.${source.kind}`)}</span>
        <span className={failed ? "bs-source__meta bs-source__meta--error" : "bs-source__meta"}>
          {failed ? failed.charAt(0).toUpperCase() + failed.slice(1) : meta}
        </span>
      </div>
      {action}
    </div>
  )
}

function Duplicates() {
  const { t } = useTranslation()
  const { reload } = useShelf()
  const [items, setItems] = useState<Duplicate[] | null>(null)
  const [merged, setMerged] = useState<{ title: string; mergeId: string | null } | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    getDuplicates().then(
      (r) => setItems(r.duplicates),
      () => setItems(null),
    )
  }, [])

  useEffect(() => {
    if (!merged) return
    const timer = window.setTimeout(() => setMerged(null), 30_000)
    return () => window.clearTimeout(timer)
  }, [merged])

  if (!items) return null

  const fail = (e: unknown) => setError(errorMessage(t, e))
  const drop = (d: Duplicate) => setItems(items.filter((x) => x.id !== d.id))

  const dismiss = (d: Duplicate) => {
    setError(null)
    dismissDuplicate(d.id).then(
      () => drop(d),
      (e: ApiError) => (e.status === 404 ? drop(d) : fail(e)),
    )
  }

  const undo = (mergeId: string) => {
    setError(null)
    unmerge(mergeId).then(
      () => {
        setMerged(null)
        reload()
      },
      (e: ApiError) => (e.status === 404 ? setMerged(null) : fail(e)),
    )
  }

  const merge = async (d: Duplicate) => {
    setError(null)
    try {
      const { book, merge_id } = await mergeBooks(d.books[0].id, d.books[1].id)
      drop(d)
      setMerged({ title: book.title, mergeId: merge_id })
      reload()
    } catch (e) {
      fail(e)
    }
  }

  return (
    <section className="bs-screen__section" id="duplicates" aria-labelledby="dup-title">
      <h2 className="bs-screen__h" id="dup-title">
        {t("duplicates.title")}
      </h2>
      {merged && (
        <div className="bs-banner bs-banner--notice" role="status">
          <p className="bs-banner__text">{t("duplicates.merged", { title: merged.title })}</p>
          {merged.mergeId && (
            <button type="button" className="bs-btn bs-btn--quiet" onClick={() => undo(merged.mergeId!)}>
              {t("book.unmerge")}
            </button>
          )}
        </div>
      )}
      {error && <p className="bs-field__error">{error}</p>}
      {items.length === 0 && !merged && <p className="bs-source__meta">{t("duplicates.none")}</p>}
      {items.map((d) => (
        <div className="bs-source" key={d.id}>
          <div className="bs-source__body">
            {d.books.map((b) => (
              <span className="bs-source__name" key={b.id}>
                {b.title}
                {b.author && <span className="bs-source__meta"> · {b.author}</span>}
              </span>
            ))}
          </div>
          <button type="button" className="bs-btn bs-btn--quiet" onClick={() => dismiss(d)}>
            {t("duplicates.notDuplicate")}
          </button>
          <button type="button" className="bs-btn bs-btn--secondary" onClick={() => merge(d)}>
            {t("book.merge")}
          </button>
        </div>
      ))}
    </section>
  )
}

export function KindleExportScreen() {
  const { t, i18n } = useTranslation()
  const online = useOnline()
  const [requestedAt, setRequestedAt] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [unavailable, setUnavailable] = useState(false)
  const [busy, setBusy] = useState(false)

  const confirm = async () => {
    setBusy(true)
    try {
      await requestKindleExport()
      setRequestedAt(new Date().toISOString())
    } catch (e) {
      if (notOfferedYet(e)) setUnavailable(true)
      else setError(errorMessage(t, e))
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="bs-screen bs-screen--sheet">
      <h1 className="bs-screen__title">{t("sources.requestKindle")}</h1>
      <p className="bs-session__text">{t("export.lead")}</p>
      <ol className="bs-steps">
        <li>
          {t("export.step1")}{" "}
          <a href="https://www.amazon.com/hz/privacy-central/data-requests/preview.html" target="_blank" rel="noreferrer">
            {t("export.step1Link")}
          </a>
        </li>
        <li>{t("export.step2")}</li>
        <li>{t("export.step3")}</li>
        <li>{t("export.step4")}</li>
      </ol>
      {requestedAt ? (
        <p className="bs-path__note" role="status">
          <Ico name="progress" />
          {t("sources.exportWaiting", {
            date: new Intl.DateTimeFormat(i18n.language, { day: "numeric", month: "long" }).format(new Date(requestedAt)),
          })}
        </p>
      ) : (
        <div className="bs-auth__actions">
          <button type="button" className="bs-btn bs-btn--primary" disabled={busy || !online} aria-busy={busy} onClick={confirm}>
            {t("export.done")}
          </button>
          <Link className="bs-btn bs-btn--quiet" to="/sources">
            {t("common.cancel")}
          </Link>
        </div>
      )}
      {unavailable && <Unavailable />}
      {error && <p className="bs-field__error">{error}</p>}
    </div>
  )
}

function Unavailable() {
  const { t } = useTranslation()
  return (
    <div className="bs-banner bs-banner--notice" role="status">
      <p className="bs-banner__text">{t("sources.notAvailableYet")}</p>
    </div>
  )
}
