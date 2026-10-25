import { useTranslation } from "react-i18next"
import { NavLink } from "react-router-dom"

const TABS = [
  { path: "/", key: "shelf" },
  { path: "/stats", key: "stats" },
  { path: "/sources", key: "sources" },
] as const

export function TabBar({ top = false }: { top?: boolean }) {
  const { t } = useTranslation()

  return (
    <nav className={top ? "bs-tabs bs-tabs--top" : "bs-tabs"} aria-label={t("tabs.label")}>
      {TABS.map((tab) => (
        <NavLink key={tab.key} to={tab.path} end={tab.path === "/"} className="bs-tab">
          {t(`tabs.${tab.key}`)}
        </NavLink>
      ))}
    </nav>
  )
}
