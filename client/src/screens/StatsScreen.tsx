import { useEffect, useState, type CSSProperties } from "react"
import { useTranslation } from "react-i18next"
import { useNavigate } from "react-router-dom"
import { getStats } from "@/api"
import { Ico } from "@/components/ui"
import type { Stats } from "@/lib/types"

const monthName = (lng: string, month: number, style: "long" | "short") =>
  new Intl.DateTimeFormat(lng, { month: style, timeZone: "UTC" }).format(new Date(Date.UTC(2000, month - 1, 1)))

const capitalize = (s: string) => s.charAt(0).toUpperCase() + s.slice(1)

export function StatsScreen() {
  const { t, i18n } = useTranslation()
  const navigate = useNavigate()
  const [year, setYear] = useState<number | undefined>()
  const [stats, setStats] = useState<Stats | null>(null)
  const [error, setError] = useState(false)
  const [month, setMonth] = useState<number | null>(null)
  const [captionX, setCaptionX] = useState(0)
  const [attempt, setAttempt] = useState(0)

  useEffect(() => {
    let live = true
    getStats(year).then(
      (s) => {
        if (!live) return
        setStats(s)
        setError(false)
      },
      () => live && setError(true),
    )
    return () => {
      live = false
    }
  }, [year, attempt])

  const lng = i18n.language
  const thisYear = new Date().getFullYear()
  const current = stats?.year ?? year ?? thisYear
  const years = stats ? [...new Set([...stats.years, current, thisYear])].filter((y) => y <= thisYear).sort((a, b) => a - b) : []
  const idx = years.indexOf(current)
  const prev = idx > 0 ? years[idx - 1] : undefined
  const next = idx >= 0 && idx < years.length - 1 ? years[idx + 1] : undefined
  const loading = !stats || stats.year !== current

  const switchYear = (y: number) => {
    setMonth(null)
    setYear(y)
  }

  const listened = stats?.listened ?? stats?.by_format.audio
  const read = stats?.read ?? stats?.by_format.ebook
  const summary = stats
    ? [
        t("stats.total", { year: stats.year, count: stats.total }),
        listened && t("stats.listened", { count: listened }),
        read && t("stats.read", { count: read }),
      ]
        .filter(Boolean)
        .join(" · ")
    : t("stats.title")

  const selected = month && stats?.months.find((m) => m.month === month)

  return (
    <div className="bs-screen">
      <h1 className="bs-sr">{t("tabs.stats")}</h1>
      {error && (
        <div className="bs-banner bs-banner--error" role="alert">
          <p className="bs-banner__text">{t("stats.loadError")}</p>
          <button type="button" className="bs-btn bs-btn--quiet" onClick={() => setAttempt((n) => n + 1)}>
            {t("book.retry")}
          </button>
        </div>
      )}
      <section className="bs-year" aria-labelledby="year-sum">
        <div className="bs-year__top">
          <h2 className="bs-year__sum" id="year-sum" aria-live="polite">
            {summary}
          </h2>
          <div className="bs-year__switch">
            {prev && (
              <button
                type="button"
                className="bs-btn bs-btn--quiet bs-btn--sm"
                aria-label={t("stats.prevYear", { year: prev })}
                onClick={() => switchYear(prev)}
              >
                {prev}
              </button>
            )}
            {next && (
              <button
                type="button"
                className="bs-btn bs-btn--quiet bs-btn--sm"
                aria-label={t("stats.nextYear", { year: next })}
                onClick={() => switchYear(next)}
              >
                {next}
              </button>
            )}
          </div>
        </div>
        <div className="bs-year__case">
          {selected && selected.books.length > 0 && (
            <div className="bs-caption bs-year__caption" style={{ "--x": `${captionX}px` } as CSSProperties}>
              <span className="bs-caption__title">{capitalize(monthName(lng, selected.month, "long"))}</span>
              <ul className="bs-year__books">
                {selected.books.map((b) => (
                  <li key={b.id}>
                    <button type="button" className="bs-btn bs-btn--quiet bs-btn--sm" onClick={() => navigate(`/?book=${b.id}`)}>
                      {b.title}
                    </button>
                  </li>
                ))}
              </ul>
            </div>
          )}
          <div className={`bs-year__scroll${!loading && stats.total === 0 ? " is-empty" : ""}`}>
            <div className="bs-year__months">
              {(loading ? Array.from({ length: 12 }, (_, i) => ({ month: i + 1, books: [] })) : stats.months).map((m) => {
                const count = m.books.length
                if (loading) {
                  return (
                    <span className="bs-stack" key={m.month} aria-hidden="true">
                      {Array.from({ length: (m.month * 7) % 3 + 1 }, (_, i) => (
                        <span className="bs-stack__book bs-cloth--blank" key={i} />
                      ))}
                    </span>
                  )
                }
                if (!count) return <span key={m.month} aria-hidden="true" />
                return (
                  <button
                    type="button"
                    className="bs-stack"
                    key={m.month}
                    aria-expanded={month === m.month}
                    aria-label={t("stats.month", { month: capitalize(monthName(lng, m.month, "long")), count })}
                    onClick={(e) => {
                      const box = e.currentTarget.closest(".bs-year__case")!.getBoundingClientRect()
                      setCaptionX(e.currentTarget.getBoundingClientRect().left - box.left)
                      setMonth(month === m.month ? null : m.month)
                    }}
                  >
                    {m.books.map((b) => (
                      <span className={`bs-stack__book bs-cloth--${b.cloth ?? "blank"}`} key={b.id}>
                        <Ico name={b.formats.includes("audio") ? "audio" : "ebook"} />
                      </span>
                    ))}
                  </button>
                )
              })}
              {!loading && stats.total === 0 && <p className="bs-year__empty">{t("stats.empty", { year: stats.year })}</p>}
            </div>
            <div className="bs-year__labels" aria-hidden="true">
              {Array.from({ length: 12 }, (_, i) => (
                <span key={i}>{monthName(lng, i + 1, "long").slice(0, 3)}</span>
              ))}
            </div>
          </div>
        </div>
        {stats && !loading && (
          <dl className="bs-year__foot">
            <div>
              <dt>{t("shelf.noDate")}</dt>
              <dd>{t("count.books", { count: stats.no_date_count })}</dd>
            </div>
            {stats.top_authors.length > 0 && (
              <div>
                <dt>{t("stats.topAuthors")}</dt>
                <dd>{stats.top_authors.map((a) => `${a.author} · ${a.count}`).join(", ")}</dd>
              </div>
            )}
          </dl>
        )}
      </section>
    </div>
  )
}
