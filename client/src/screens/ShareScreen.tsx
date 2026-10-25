import { useEffect, useState } from "react"
import { useTranslation } from "react-i18next"
import { Link, useSearchParams } from "react-router-dom"
import { share, shareAdd } from "@/api"
import { SearchAnswer } from "@/components/SearchAnswer"
import { Choices, Field, Ico } from "@/components/ui"
import type { ApiError } from "@/lib/api"
import { useShelf } from "@/lib/shelf"
import type { BookSummary, Format, SearchResult, ShareAnswer, Status } from "@/lib/types"
import { useOnline } from "@/lib/useOnline"
import { errorMessage, primaryEdition, statusLine } from "@/lib/vocab"

// Android share_target lands here (GET /share?title&text&url); the server matches links and text.
export function ShareScreen() {
  const { t, i18n } = useTranslation()
  const [params] = useSearchParams()
  const { reload } = useShelf()
  const online = useOnline()
  const locale = i18n.language.slice(0, 2)
  const title0 = params.get("title") ?? ""
  const text0 = params.get("text") ?? ""
  const url0 = params.get("url") ?? ""
  const empty = !`${title0}${text0}${url0}`.trim()
  const [answer, setAnswer] = useState<ShareAnswer | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [title, setTitle] = useState("")
  const [choosingFormat, setChoosingFormat] = useState(false)
  const [saved, setSaved] = useState<string | null>(null)

  useEffect(() => {
    if (empty) return
    share({ title: title0, text: text0, url: url0, locale }).then(
      (a) => {
        setAnswer(a)
        setTitle(a.suggestion?.title ?? "")
      },
      (e) => setError(errorMessage(t, e)),
    )
  }, [title0, text0, url0, empty, locale, t])

  const add = async (edition: { format: Format; status: Status }) => {
    if (!title.trim()) return setError(t("share.typeTitle"))
    setError(null)
    const s = answer?.suggestion
    try {
      const { message } = await shareAdd(
        { title: title.trim(), author: s?.author ?? null, store: s?.store ?? null, external_id: s?.external_id ?? null },
        edition,
        locale,
      )
      setSaved(message)
      reload()
    } catch (e) {
      const existing = (e as ApiError).body?.existing as BookSummary | undefined
      setError(
        (e as ApiError).code === "duplicate" && existing
          ? t("entry.duplicate", { status: statusLine(t, i18n.language, primaryEdition(existing)) })
          : errorMessage(t, e),
      )
    }
  }

  let body
  if (empty) body = <p className="bs-answer">{t("share.nothing")}</p>
  else if (saved) {
    body = (
      <p className="bs-answer" role="status">
        {saved}
      </p>
    )
  } else if (!answer) body = error ? null : <p className="bs-answer">{t("share.looking")}</p>
  else if (answer.answer.kind === "not_found" || answer.answer.kind === "unrecognized") {
    body = (
      <div className="bs-answer" role="status">
        <span className="bs-answer__title">{t(`answer.${answer.answer.kind}`)}</span>
        {!answer.suggestion?.title && (
          <div className="bs-answer__actions">
            <Field label={t("share.titlePrompt")} value={title} onChange={(e) => setTitle(e.target.value)} />
          </div>
        )}
        {choosingFormat ? (
          <Choices<Format>
            legend={t("share.formatPrompt")}
            value={"" as Format}
            disabled={!online}
            onChange={(format) => add({ format, status: "want" })}
            options={[
              { value: "audio", label: t("format.audio"), icon: "audio" },
              { value: "ebook", label: t("format.ebook"), icon: "ebook" },
            ]}
          />
        ) : (
          <span className="bs-answer__actions">
            <button type="button" className="bs-btn bs-btn--secondary bs-btn--sm" disabled={!online} onClick={() => setChoosingFormat(true)}>
              <Ico name="want" />
              {t("search.want")}
            </button>
            <button type="button" className="bs-btn bs-btn--secondary bs-btn--sm" disabled={!online} onClick={() => add({ format: "ebook", status: "done" })}>
              {t("search.read")}
            </button>
            <button type="button" className="bs-btn bs-btn--secondary bs-btn--sm" disabled={!online} onClick={() => add({ format: "audio", status: "done" })}>
              {t("search.listened")}
            </button>
          </span>
        )}
      </div>
    )
  } else {
    body = (
      <div className="bs-answer" role="status">
        <SearchAnswer query={answer.query} result={answer as SearchResult} onWant={() => {}} onWrite={() => {}} />
      </div>
    )
  }

  return (
    <div className="bs-screen">
      <h1 className="bs-screen__title">{t("share.title")}</h1>
      {answer?.query && <p className="bs-share__query">{answer.query}</p>}
      {body}
      {error && <p className="bs-answer bs-field__error">{error}</p>}
      <div>
        <Link className="bs-btn bs-btn--quiet" to="/">
          {t("sources.toBookcase")}
        </Link>
      </div>
    </div>
  )
}
