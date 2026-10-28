import { useTranslation } from "react-i18next"
import { GENRES, type Genre } from "@/lib/types"

const R = 80

export function GenreStar({ counts, total }: { counts: Partial<Record<Genre, number>>; total: number }) {
  const { t } = useTranslation()
  if (!GENRES.some((g) => counts[g])) return null

  const max = Math.max(...GENRES.map((g) => counts[g] ?? 0))
  const axes = GENRES.map((genre, i) => {
    const angle = (i / GENRES.length) * 2 * Math.PI - Math.PI / 2
    const count = counts[genre] ?? 0
    const at = (r: number) => [Math.cos(angle) * r, Math.sin(angle) * r] as const
    return { genre, count, cos: Math.cos(angle), sin: Math.sin(angle), at, point: at((R * count) / max) }
  })
  const label = (genre: Genre, count: number) => `${Math.round((count / total) * 100)}% ${t(`genre.${genre}`)}`

  return (
    <figure className="bs-genres">
      <figcaption className="bs-genres__title">{t("stats.genres")}</figcaption>
      <svg viewBox="-200 -130 400 260" role="img" aria-label={axes.map((a) => label(a.genre, a.count)).join(", ")}>
        {axes.map(({ genre, at }) => (
          <line key={genre} className="bs-genres__axis" x1={0} y1={0} x2={at(R)[0]} y2={at(R)[1]} />
        ))}
        <polygon className="bs-genres__area" points={axes.map((a) => a.point.join(",")).join(" ")} />
        {axes.map(({ genre, point }) => (
          <circle key={genre} className="bs-genres__dot" cx={point[0]} cy={point[1]} r={3.5} />
        ))}
        {axes.map(({ genre, count, cos, sin, at }) => {
          const [x, y] = at(R + 14)
          const anchor = Math.abs(cos) < 0.3 ? "middle" : cos > 0 ? "start" : "end"
          const dy = sin < -0.3 ? -18 : sin > 0.3 ? 12 : -4
          return (
            <text key={genre} className="bs-genres__label" x={x} y={y + dy} textAnchor={anchor}>
              <tspan x={x}>{Math.round((count / total) * 100)}%</tspan>
              <tspan x={x} dy={15}>
                {t(`genre.${genre}`)}
              </tspan>
            </text>
          )
        })}
      </svg>
    </figure>
  )
}
