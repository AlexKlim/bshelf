import { useTranslation } from "react-i18next"
import { Route, Routes } from "react-router-dom"
import { TabBar } from "@/components/TabBar"
import { useMediaQuery } from "@/lib/useMediaQuery"

function Placeholder({ title }: { title: string }) {
  return <h1 className="app__title">{title}</h1>
}

export default function App() {
  const { t } = useTranslation()
  const desktop = useMediaQuery("(min-width: 1200px)")

  return (
    <div className="app">
      <main className="app__main">
        <Routes>
          <Route path="/" element={<Placeholder title={t("tabs.shelf")} />} />
          <Route path="/stats" element={<Placeholder title={t("tabs.stats")} />} />
          <Route path="/sources" element={<Placeholder title={t("tabs.sources")} />} />
          <Route path="/profile" element={<Placeholder title={t("profile.title")} />} />
        </Routes>
      </main>
      <div className="app__tabs">
        <TabBar top={desktop} />
      </div>
    </div>
  )
}
