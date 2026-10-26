import { useTranslation } from "react-i18next"
import { useNavigate } from "react-router-dom"
import { Ico } from "./ui"

export function EmptyCase({ disabled, onAdd }: { disabled?: boolean; onAdd: () => void }) {
  const { t } = useTranslation()
  const navigate = useNavigate()

  return (
    <div className="bs-empty">
      <div className="bs-case" aria-hidden="true">
        <div className="bs-shelf">
          <ul className="bs-shelf__row" />
          <div className="bs-shelf__plank" />
        </div>
        <div className="bs-shelf">
          <ul className="bs-shelf__row" />
          <div className="bs-shelf__plank" />
        </div>
      </div>
      <section className="bs-onboard" aria-labelledby="onboard-title">
        <h2 className="bs-onboard__title" id="onboard-title">
          {t("empty.title")}
        </h2>
        <p className="bs-onboard__lead">{t("empty.lead")}</p>
        <ul className="bs-paths">
          <li className="bs-path">
            <button type="button" className="bs-btn bs-btn--primary" disabled={disabled} onClick={() => navigate("/sources/litres")}>
              {t("sources.litresSignIn")}
            </button>
            <p className="bs-path__note">{t("empty.litresNote")}</p>
          </li>
          <li className="bs-path">
            <button type="button" className="bs-btn bs-btn--secondary" disabled={disabled} onClick={() => navigate("/sources/kindle")}>
              {t("sources.kindleSync")}
            </button>
            <p className="bs-path__note">{t("empty.kindleNote")}</p>
          </li>
          <li className="bs-path">
            <button type="button" className="bs-btn bs-btn--quiet" disabled={disabled} onClick={onAdd}>
              <Ico name="pen" />
              {t("shelf.addBook")}
            </button>
          </li>
        </ul>
      </section>
    </div>
  )
}
