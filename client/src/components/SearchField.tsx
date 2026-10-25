import { useEffect, useState } from "react"
import { useTranslation } from "react-i18next"
import { addBook, search } from "@/api"
import type { ApiError } from "@/lib/api"
import type { SearchResult } from "@/lib/types"
import type { EntryDraft } from "./EntryForm"
import { SearchAnswer } from "./SearchAnswer"
import { Ico } from "./ui"
import { errorMessage } from "@/lib/vocab"

type Props = {
  disabled?: boolean
  onMatches: (ids: Set<string>) => void
  onWrite: (draft: EntryDraft) => void
  onAdded: () => void
}

export function SearchField({ disabled, onMatches, onWrite, onAdded }: Props) {
  const { t } = useTranslation()
  const [query, setQuery] = useState("")
  const [result, setResult] = useState<SearchResult | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [version, setVersion] = useState(0)
  const q = query.trim()

  useEffect(() => {
    if (!q) return
    let live = true
    const timer = window.setTimeout(() => {
      search(q)
        .then((r) => {
          if (!live) return
          setResult(r)
          setError(null)
          onMatches(new Set(r.answer.kind === "not_found" ? [] : r.books.map((b) => b.id)))
        })
        .catch((e: ApiError) => live && setError(errorMessage(t, e)))
    }, 250)
    return () => {
      live = false
      window.clearTimeout(timer)
    }
  }, [q, version, onMatches, t])

  const change = (value: string) => {
    setQuery(value)
    if (!value.trim()) {
      setResult(null)
      setError(null)
      onMatches(new Set())
    }
  }

  const want = async () => {
    try {
      await addBook({ title: q, edition: { format: "unknown", status: "want" } })
      onAdded()
      setVersion((v) => v + 1)
    } catch (e) {
      setError(errorMessage(t, e))
    }
  }

  return (
    <div className="bs-searchbox">
      <label className="bs-search">
        <Ico name="search" />
        <span className="bs-sr">{t("search.label")}</span>
        <input
          className="bs-search__input"
          type="search"
          placeholder={t("search.placeholder")}
          value={query}
          onChange={(e) => change(e.target.value)}
        />
        {query && (
          <button type="button" className="bs-iconbtn" aria-label={t("search.clear")} onClick={() => change("")}>
            <Ico name="close" />
          </button>
        )}
      </label>
      <div className="bs-answer" role="status">
        {q && error && <span>{error}</span>}
        {q && result && !error && (
          <SearchAnswer query={q} result={result} disabled={disabled} onWant={want} onWrite={onWrite} />
        )}
      </div>
    </div>
  )
}
