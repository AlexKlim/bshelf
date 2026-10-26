import { useEffect, useRef, useState } from "react"
import { useTranslation } from "react-i18next"
import { tidyLibrary } from "@/api"

type DeskState = { kind: "idle" | "busy" | "error" } | { kind: "queued"; count: number; duplicates: boolean }

const RELOADS = [15_000, 60_000]

export function LibrarianDesk({ disabled, onTidied }: { disabled?: boolean; onTidied: () => void }) {
  const { t } = useTranslation()
  const [state, setState] = useState<DeskState>({ kind: "idle" })
  const timers = useRef<number[]>([])

  useEffect(() => () => timers.current.forEach(window.clearTimeout), [])

  const tidy = async () => {
    setState({ kind: "busy" })
    try {
      const { queued, duplicates } = await tidyLibrary()
      setState({ kind: "queued", count: queued, duplicates })
      if (queued || duplicates) timers.current = RELOADS.map((ms) => window.setTimeout(onTidied, ms))
    } catch {
      setState({ kind: "error" })
    }
  }

  const note =
    state.kind === "queued"
      ? state.count
        ? t("desk.queued", { count: state.count })
        : state.duplicates
          ? t("desk.duplicates")
          : t("desk.nothing")
      : t(`desk.${state.kind}`)

  return (
    <section className="bs-desk" aria-labelledby="desk-title">
      <div className="bs-desk__top">
        <h2 className="bs-desk__plaque" id="desk-title">
          {t("desk.title")}
        </h2>
        <p className="bs-desk__note" aria-live="polite">
          {note}
        </p>
        <button type="button" className="bs-btn bs-btn--secondary" disabled={disabled || state.kind === "busy"} onClick={tidy}>
          {t("desk.tidy")}
        </button>
      </div>
      <div className="bs-desk__front" aria-hidden="true" />
    </section>
  )
}
