import { useTranslation } from "react-i18next"
import { useNavigate } from "react-router-dom"
import type { BannerEvent } from "@/lib/banner"
import { Ico } from "./ui"

export function SourceBanner({ event, onDismiss }: { event: BannerEvent; onDismiss: () => void }) {
  const { t } = useTranslation()
  const navigate = useNavigate()

  if (event.kind === "offline") {
    return (
      <div className="bs-banner bs-banner--notice" role="status">
        <p className="bs-banner__text">{t("banner.offline")}</p>
      </div>
    )
  }

  if (event.kind === "source_error") {
    return (
      <div className="bs-banner bs-banner--error" role="alert">
        <p className="bs-banner__text">
          <b>{t(`banner.error.${event.source}`)}</b> {t(`sourceErrors.${event.error}`, { defaultValue: t("sourceErrors.generic") })}
        </p>
        <button type="button" className="bs-btn bs-btn--quiet" onClick={() => navigate("/sources")}>
          {t("banner.signInAgain")}
        </button>
      </div>
    )
  }

  const notice = {
    litres_reminder: { text: t("banner.litresReminder"), action: t("banner.signIn"), to: "/sources/litres" },
    possible_duplicates: {
      text: t("banner.duplicates", { count: event.kind === "possible_duplicates" ? event.count : 0 }),
      action: t("banner.review"),
      to: "/sources#duplicates",
    },
  }[event.kind]

  return (
    <div className="bs-banner bs-banner--notice" role="status">
      <p className="bs-banner__text">{notice.text}</p>
      <button type="button" className="bs-btn bs-btn--quiet" onClick={() => navigate(notice.to)}>
        {notice.action}
      </button>
      {event.dismissible && (
        <button type="button" className="bs-iconbtn" aria-label={t("banner.dismiss")} onClick={onDismiss}>
          <Ico name="close" />
        </button>
      )}
    </div>
  )
}
