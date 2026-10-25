import { useTranslation } from "react-i18next"
import type { SearchResult } from "@/lib/types"
import { answerLine, formatsOf } from "@/lib/vocab"
import type { EntryDraft } from "./EntryForm"
import { Ico, StatusMark } from "./ui"

type Props = {
  query: string
  result: SearchResult
  disabled?: boolean
  onWant: () => void
  onWrite: (draft: EntryDraft) => void
}

export function SearchAnswer({ query, result, disabled, onWant, onWrite }: Props) {
  const { t, i18n } = useTranslation()
  const line = answerLine(t, i18n.language, result)
  const single = result.answer.kind !== "similar" && result.answer.kind !== "not_found" ? result.books[0] : null

  return (
    <>
      {single ? (
        <>
          <span className="bs-answer__title">{single.title}</span>
          <StatusMark text={line} formats={formatsOf(single)} />
        </>
      ) : (
        <span className="bs-answer__title">{line}</span>
      )}
      {result.answer.kind === "similar" && (
        <ul className="bs-answer__list">
          {result.books.map((b) => (
            <li key={b.id}>
              {b.title}
              {b.author ? `, ${b.author}` : ""}
            </li>
          ))}
        </ul>
      )}
      {result.answer.kind === "not_found" && (
        <span className="bs-answer__actions">
          <button type="button" className="bs-btn bs-btn--secondary bs-btn--sm" disabled={disabled} onClick={onWant}>
            <Ico name="want" />
            {t("search.want")}
          </button>
          <button
            type="button"
            className="bs-btn bs-btn--secondary bs-btn--sm"
            disabled={disabled}
            onClick={() => onWrite({ title: query, format: "ebook", status: "done" })}
          >
            {t("search.read")}
          </button>
          <button
            type="button"
            className="bs-btn bs-btn--secondary bs-btn--sm"
            disabled={disabled}
            onClick={() => onWrite({ title: query, format: "audio", status: "done" })}
          >
            {t("search.listened")}
          </button>
        </span>
      )}
    </>
  )
}
