import { useTranslation } from "react-i18next"
import { useLocation, useNavigate } from "react-router-dom"

const TABS = [
  { path: "/", key: "shelf" },
  { path: "/stats", key: "stats" },
  { path: "/sources", key: "sources" },
] as const

export function TabBar({ top = false }: { top?: boolean }) {
  const { t } = useTranslation()
  const { pathname } = useLocation()
  const navigate = useNavigate()

  return (
    <nav className={top ? "bs-tabs bs-tabs--top" : "bs-tabs"} role="tablist" aria-label={t("tabs.label")}>
      {TABS.map((tab) => (
        <button
          key={tab.key}
          type="button"
          role="tab"
          className="bs-tab"
          aria-selected={pathname === tab.path}
          onClick={() => navigate(tab.path)}
        >
          {t(`tabs.${tab.key}`)}
        </button>
      ))}
    </nav>
  )
}
