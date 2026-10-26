import { useCallback, useEffect, useRef, useState, type CSSProperties, type ReactNode } from "react"
import { useTranslation } from "react-i18next"
import { useNavigate } from "react-router-dom"
import { cancelRemoteSession, getRemoteSession, remoteViewer, startRemoteSession } from "@/api"
import { Ico } from "@/components/ui"
import type { ApiError } from "@/lib/api"
import { useShelf } from "@/lib/shelf"
import type { RemoteSession } from "@/lib/types"
import { errorMessage, isActive, syncResult } from "@/lib/vocab"

// Steel draws the page at the frame's own size, so the stream is never scaled. The chrome is our bar plus Steel's toolbar.
const FRAME_MAX = 1280
const FRAME_CHROME = 100

type Purpose = RemoteSession["purpose"]

const storageKey = (purpose: Purpose) => `bs:remote:${purpose}`

function remember(purpose: Purpose, id: string | null) {
  try {
    if (id) sessionStorage.setItem(storageKey(purpose), id)
    else sessionStorage.removeItem(storageKey(purpose))
  } catch {
    /* reconnect after a reload is a convenience; POST also returns the running session */
  }
}

function loginWindowMs(session: RemoteSession) {
  if (session.login_window_seconds) return session.login_window_seconds * 1000
  if (session.expires_at && session.created_at) return Date.parse(session.expires_at) - Date.parse(session.created_at)
  return null
}

function recall(purpose: Purpose) {
  try {
    return sessionStorage.getItem(storageKey(purpose))
  } catch {
    return null
  }
}

export function RemoteBrowserScreen({ purpose }: { purpose: Purpose }) {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const { reload } = useShelf()
  const [session, setSession] = useState<RemoteSession | null>(null)
  const [restoring, setRestoring] = useState(() => !!recall(purpose))
  const [starting, setStarting] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [unavailable, setUnavailable] = useState(false)
  const [viewUrl, setViewUrl] = useState<string | null>(null)
  const [deadline, setDeadline] = useState<number | null>(null)
  const [now, setNow] = useState(() => Date.now())
  const viewerFor = useRef<string | null>(null)
  const ns = session?.purpose ?? purpose

  const apply = useCallback(
    (next: RemoteSession) => {
      setSession(next)
      if (next.seconds_left != null) setDeadline(Date.now() + next.seconds_left * 1000)
      if (!isActive(next.status)) remember(next.purpose, null)
      if (next.status === "done") reload()
      if (next.status !== "live") {
        viewerFor.current = null
        setViewUrl(null)
      }
    },
    [reload],
  )

  const refresh = useCallback(
    (id: string) =>
      getRemoteSession(id).then(
        ({ session }) => apply(session),
        (e: ApiError) => {
          if (e.status !== 404) return
          remember(purpose, null)
          setSession(null)
        },
      ),
    [apply, purpose],
  )

  useEffect(() => {
    const id = recall(purpose)
    if (id) refresh(id).finally(() => setRestoring(false))
  }, [purpose, refresh])

  // The viewer token works once, for a minute: take a fresh one every time the live view (re)mounts.
  useEffect(() => {
    if (session?.status !== "live" || viewerFor.current === session.id) return
    viewerFor.current = session.id
    remoteViewer(session.id).then(
      ({ url }) => setViewUrl(url),
      () => (viewerFor.current = null),
    )
  }, [session])

  const active = !!session && isActive(session.status)
  const sessionId = session?.id

  useEffect(() => {
    if (!active || !sessionId) return
    const poll = window.setInterval(() => refresh(sessionId), 1500)
    const tick = window.setInterval(() => setNow(Date.now()), 1000)
    const onVisible = () => {
      if (document.visibilityState !== "visible") return
      viewerFor.current = null
      refresh(sessionId)
    }
    document.addEventListener("visibilitychange", onVisible)
    return () => {
      window.clearInterval(poll)
      window.clearInterval(tick)
      document.removeEventListener("visibilitychange", onVisible)
    }
  }, [active, sessionId, refresh])

  const start = async () => {
    setStarting(true)
    setError(null)
    try {
      const viewport = { width: Math.min(window.innerWidth, FRAME_MAX), height: window.innerHeight - FRAME_CHROME }
      const { session } = await startRemoteSession(purpose, viewport)
      remember(session.purpose, session.id)
      apply(session)
    } catch (e) {
      if ((e as ApiError).code === "unavailable") setUnavailable(true)
      else setError(errorMessage(t, e))
    } finally {
      setStarting(false)
    }
  }

  const cancel = () => {
    if (session && active) cancelRemoteSession(session.id).catch(() => {})
    remember(session?.purpose ?? purpose, null)
    navigate("/sources")
  }

  const title = t(`remote.${ns}.title`)
  if (restoring) return <Sheet title={title}>{null}</Sheet>

  const cancelButton = (
    <button type="button" className="bs-btn bs-btn--quiet bs-btn--sm" onClick={cancel}>
      {t("remote.cancel")}
    </button>
  )

  if (unavailable) {
    return (
      <Sheet title={title}>
        <h2 className="bs-session__h">{t("remote.unavailable")}</h2>
        <p className="bs-session__text">{t("remote.unavailableLead")}</p>
        <div className="bs-session__actions">
          <button type="button" className="bs-btn bs-btn--secondary" onClick={() => navigate("/sources")}>
            {t("sources.backToSources")}
          </button>
        </div>
      </Sheet>
    )
  }

  if (!session || session.interruption === "aborted") {
    return (
      <Sheet title={title}>
        <h2 className="bs-session__h">{t(`remote.${ns}.heading`)}</h2>
        <p className="bs-session__text">{t(`remote.${ns}.disclosure`)}</p>
        <ul className="bs-facts">
          <li>
            <Ico name="done" />
            {t("remote.factPassword")}
          </li>
          <li>
            <Ico name="done" />
            {t("remote.factSession")}
          </li>
          {ns === "kindle" && (
            <li>
              <Ico name="done" />
              {t("remote.fact2fa")}
            </li>
          )}
        </ul>
        {error && <p className="bs-field__error">{error}</p>}
        <div className="bs-session__actions">
          <button type="button" className="bs-btn bs-btn--primary" disabled={starting} aria-busy={starting} onClick={start}>
            {t("remote.continue")}
          </button>
          <button type="button" className="bs-btn bs-btn--quiet" onClick={() => navigate("/sources")}>
            {t("common.cancel")}
          </button>
        </div>
      </Sheet>
    )
  }

  if (session.status === "queued") {
    return (
      <Sheet title={title} action={cancelButton}>
        <h2 className="bs-session__h">{t("remote.queued")}</h2>
        <p className="bs-session__text" aria-live="polite">
          {t("remote.queuePosition", { position: session.queue_position ?? 1 })}
        </p>
      </Sheet>
    )
  }

  if (session.status === "connecting" || session.status === "live") {
    const left = deadline ? Math.max(0, deadline - now) : 0
    const time = `${Math.floor(left / 60000)}:${String(Math.floor((left % 60000) / 1000)).padStart(2, "0")}`
    const live = session.status === "live"
    const windowMs = loginWindowMs(session)
    return (
      <section className="bs-session bs-session--full" aria-label={t(`remote.${ns}.heading`)}>
        <div
          className="bs-session__bar"
          style={live && windowMs ? ({ "--left": `${Math.min(100, (left / windowMs) * 100)}%` } as CSSProperties) : undefined}
        >
          <span className="bs-session__title">{t(`remote.${ns}.heading`)}</span>
          {live && (
            <span
              className={`bs-session__timer${left < 60000 ? " bs-session__timer--low" : ""}`}
              role="timer"
              aria-label={t("remote.timeLeft", { time })}
            >
              {time}
            </span>
          )}
          {cancelButton}
        </div>
        <div className="bs-session__view">
          {live && viewUrl ? (
            <iframe key={viewUrl} className="bs-session__frame" src={viewUrl} title={t(`remote.${ns}.frame`)} />
          ) : (
            <div className="bs-skeleton" aria-busy="true">
              <span />
              <span />
              <span />
              <span />
              <p>{t("remote.connecting")}</p>
            </div>
          )}
        </div>
      </section>
    )
  }

  if (session.status === "collecting") {
    return (
      <Sheet title={title}>
        <h2 className="bs-session__h">{t("remote.collecting")}</h2>
        <ul className="bs-facts" aria-live="polite">
          <li>
            <Ico name="done" />
            {t("remote.signedIn")}
          </li>
          {session.steps.map((step) => (
            <li key={step.key} className={step.state === "pending" ? "is-pending" : undefined}>
              <Ico name={step.state === "done" ? "done" : "progress"} />
              {t(`remote.step.${step.key}`, { defaultValue: step.key })}
              {step.state === "pending" ? "…" : ""}
            </li>
          ))}
        </ul>
        <p className="bs-session__text">{t("remote.canLeave")}</p>
        <div className="bs-session__actions">
          <button type="button" className="bs-btn bs-btn--secondary" onClick={() => navigate("/")}>
            {t("sources.toBookcase")}
          </button>
        </div>
      </Sheet>
    )
  }

  if (session.status === "done") {
    return (
      <Sheet title={title}>
        <h2 className="bs-session__h" role="status">
          {session.result ? syncResult(t, session.result) : t("remote.done")}
        </h2>
        <div className="bs-session__actions">
          <button type="button" className="bs-btn bs-btn--primary" onClick={() => navigate("/")}>
            {t("sources.toBookcase")}
          </button>
        </div>
      </Sheet>
    )
  }

  return (
    <Sheet title={title}>
      <h2 className="bs-session__h" role="alert">
        {t(`remote.failure.${session.interruption ?? "deploy_interrupted"}`, { store: t(`remote.${ns}.store`) })}
      </h2>
      <div className="bs-session__actions">
        <button type="button" className="bs-btn bs-btn--primary" onClick={() => setSession(null)}>
          {t("remote.again")}
        </button>
        <button type="button" className="bs-btn bs-btn--quiet" onClick={() => navigate("/")}>
          {t("sources.toBookcase")}
        </button>
      </div>
    </Sheet>
  )
}

function Sheet({ title, action, children }: { title: string; action?: ReactNode; children: ReactNode }) {
  return (
    <section className="bs-session bs-session--full" aria-label={title}>
      <div className="bs-session__bar">
        <span className="bs-session__title">{title}</span>
        {action}
      </div>
      <div className="bs-session__body bs-session__body--page">{children}</div>
    </section>
  )
}
