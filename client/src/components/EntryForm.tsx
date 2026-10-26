import { useState, type FormEvent } from "react"
import { useTranslation } from "react-i18next"
import { addBook, type NewBook } from "@/api"
import type { ApiError } from "@/lib/api"
import type { BookDetail, BookSummary, Status } from "@/lib/types"
import { duplicateMessage, errorMessage, statusWord } from "@/lib/vocab"
import { Choices, Field, Ico, MonthField } from "./ui"

export type EntryDraft = { title?: string; format?: "audio" | "ebook"; status?: Status }

type Props = {
  draft?: EntryDraft
  disabled?: boolean
  onSaved: (book: BookDetail) => void
  onCancel: () => void
}

export function EntryForm({ draft = {}, disabled, onSaved, onCancel }: Props) {
  const { t, i18n } = useTranslation()
  const [title, setTitle] = useState(draft.title ?? "")
  const [author, setAuthor] = useState("")
  const [format, setFormat] = useState<"audio" | "ebook">(draft.format ?? "ebook")
  const [status, setStatus] = useState<Status>(draft.status ?? "want")
  const [when, setWhen] = useState("")
  const [errors, setErrors] = useState<Record<string, string>>({})
  const [busy, setBusy] = useState(false)
  const dated = status === "done" || status === "in_progress"

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    if (!title.trim()) return setErrors({ title: t("errors.blank") })
    const edition: NewBook["edition"] = { format, status }
    if (dated && when) edition[status === "done" ? "finished_at" : "started_at"] = `${when}-01`
    setBusy(true)
    setErrors({})
    try {
      const { book } = await addBook({ title: title.trim(), author: author.trim() || undefined, edition })
      onSaved(book)
    } catch (err) {
      const error = err as ApiError
      if (error.code === "duplicate") {
        setErrors({ title: duplicateMessage(t, i18n.language, error.body.existing as BookSummary | undefined) })
      } else {
        const field = error.errors[0]?.field
        setErrors({ [field === "author" ? "author" : "title"]: errorMessage(t, error) })
      }
    } finally {
      setBusy(false)
    }
  }

  return (
    <form className="bs-entry" onSubmit={submit} noValidate>
      <h2 className="bs-entry__title">{t("entry.title")}</h2>
      <Field
        hand
        label={t("entry.bookTitle")}
        value={title}
        error={errors.title}
        autoFocus={!draft.title}
        onChange={(e) => setTitle(e.target.value)}
      />
      <Field
        hand
        label={t("entry.author")}
        placeholder={t("entry.authorPlaceholder")}
        value={author}
        error={errors.author}
        onChange={(e) => setAuthor(e.target.value)}
      />
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
        options={[
          { value: "want", label: statusWord(t, "want", format), icon: "want" },
          { value: "owned", label: statusWord(t, "owned", format), icon: "owned" },
          { value: "in_progress", label: statusWord(t, "in_progress", format), icon: "progress" },
          { value: "done", label: statusWord(t, "done", format), icon: "done" },
        ]}
      />
      {dated && (
        <MonthField label={t("entry.when")} value={when} onChange={setWhen} />
      )}
      <div className="bs-entry__actions">
        <button type="button" className="bs-btn bs-btn--quiet" onClick={onCancel}>
          {t("common.cancel")}
        </button>
        <button type="submit" className="bs-btn bs-btn--primary" disabled={disabled} aria-busy={busy}>
          <Ico name="pen" />
          {busy ? t("entry.saving") : t("entry.save")}
        </button>
      </div>
    </form>
  )
}
