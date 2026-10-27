import { useTranslation } from "react-i18next"
import { useTidy } from "@/lib/useTidy"

export function LibrarianDesk({ disabled, onTidied }: { disabled?: boolean; onTidied: () => void }) {
  const { t } = useTranslation()
  const { busy, note, tidy } = useTidy(onTidied)

  return (
    <section className="bs-desk" aria-labelledby="desk-title">
      <div className="bs-desk__top">
        <h2 className="bs-desk__plaque" id="desk-title">
          {t("desk.title")}
        </h2>
        <p className="bs-desk__note" aria-live="polite">
          {note}
        </p>
        <button type="button" className="bs-btn bs-btn--secondary" disabled={disabled || busy} onClick={tidy}>
          {t("desk.tidy")}
        </button>
      </div>
      <div className="bs-desk__front" aria-hidden="true" />
    </section>
  )
}
