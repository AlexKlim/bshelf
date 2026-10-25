import { useEffect, type CSSProperties } from "react"
import { useTranslation } from "react-i18next"
import { Link } from "react-router-dom"
import { FormatIcons, Ico } from "@/components/ui"
import "./LandingScreen.css"

type Format = "audio" | "ebook"
type SampleSpine = [cloth: string, lang: string, width: number, height: number, title: string, author: string, formats: Format[]]

const SOURCE_URL = "https://github.com/AlexKlim/bshelf"

const NOW: SampleSpine[] = [
  ["slate", "ru", 34, 160, "Дюна", "Фрэнк Герберт", ["audio"]],
  ["ochre", "ru", 32, 168, "Пикник на обочине", "Стругацкие", ["audio", "ebook"]],
  ["navy", "en", 40, 176, "Project Hail Mary", "Andy Weir", ["ebook"]],
  ["linen", "ru", 30, 144, "Generation «П»", "Пелевин", ["audio"]],
  ["oxblood", "ru", 36, 172, "Мастер и Маргарита", "Булгаков", ["audio"]],
  ["bottle", "en", 34, 160, "Sapiens", "Yuval Noah Harari", ["ebook"]],
]

const YEAR: SampleSpine[] = [
  ["plum", "ru", 44, 184, "Война и мир", "Лев Толстой", ["audio"]],
  ["navy", "en", 36, 168, "Thinking, Fast and Slow", "Daniel Kahneman", ["audio"]],
  ["sage", "ru", 32, 148, "Солярис", "Станислав Лем", ["audio"]],
  ["slate", "ru", 38, 176, "Мессия Дюны", "Фрэнк Герберт", ["audio"]],
  ["linen", "en", 32, 160, "Educated", "Tara Westover", ["ebook"]],
  ["oxblood", "ru", 36, 168, "Анна Каренина", "Лев Толстой", ["audio"]],
  ["ochre", "ru", 30, 152, "Улитка на склоне", "Стругацкие", ["audio"]],
]

const MONTHS: [string, Format][][] = [
  [["oxblood", "audio"]],
  [["navy", "ebook"], ["ochre", "audio"]],
  [],
  [["bottle", "audio"], ["plum", "audio"], ["linen", "ebook"]],
  [["slate", "audio"]],
  [["sage", "ebook"], ["oxblood", "audio"]],
  [["plum", "audio"], ["navy", "ebook"]],
  [],
  [["ochre", "audio"]],
  [["bottle", "ebook"], ["slate", "audio"], ["oxblood", "audio"]],
  [["linen", "ebook"], ["navy", "audio"]],
  [["plum", "ebook"]],
]

const PULLED = "Пикник на обочине"

const monthLabel = (lng: string, month: number) =>
  new Intl.DateTimeFormat(lng, { month: "long", timeZone: "UTC" }).format(new Date(Date.UTC(2000, month, 1))).slice(0, 3)

function Spines({ books }: { books: SampleSpine[] }) {
  return books.map(([cloth, lang, w, h, title, author, formats]) => (
    <li key={title}>
      <span
        className={`bs-spine bs-cloth--${cloth}${title === PULLED ? " is-pulled" : ""}`}
        lang={lang}
        style={{ "--spine-w": `${w}px`, "--spine-h": `${h}px` } as CSSProperties}
      >
        <span className="bs-spine__text">
          <span className="bs-spine__title">{title}</span>
          <span className="bs-spine__author">{author}</span>
        </span>
        <span className="bs-spine__format">
          {formats.map((f) => (
            <Ico key={f} name={f} />
          ))}
        </span>
      </span>
    </li>
  ))
}

export function LandingScreen() {
  const { t, i18n } = useTranslation()
  const lng = i18n.language
  const list = <T,>(key: string) => t(key, { returnObjects: true }) as T[]

  useEffect(() => {
    const previous = document.title
    document.title = t("landing.title")
    return () => {
      document.title = previous
    }
  }, [t])

  const create = (
    <Link className="bs-btn bs-btn--primary" to="/register">
      {t("landing.create")}
    </Link>
  )

  return (
    <div className="lp">
      <header className="lp-header">
        <div className="lp-wrap lp-header__bar">
          <p className="bs-wordmark lp-header__mark">{t("app.name")}</p>
          <nav aria-label={t("landing.nav")} className="lp-header__nav">
            <a href="#how">{t("landing.how")}</a>
            <a href="#faq">{t("landing.faq")}</a>
            <a href={SOURCE_URL} target="_blank" rel="noreferrer">{t("footer.source")}</a>
          </nav>
          <div className="lp-actions">
            <Link className="bs-btn bs-btn--quiet" to="/login">
              {t("auth.signIn")}
            </Link>
            {create}
          </div>
        </div>
      </header>

      <main>
        <section className="lp-wrap lp-hero">
          <div className="lp-row">
            <div className="lp-text">
              <h1 className="lp-h1">{t("landing.h1")}</h1>
              <p className="lp-lead">{t("landing.lead")}</p>
              <div className="lp-actions lp-actions--hero">
                {create}
                <a className="bs-btn bs-btn--secondary" href="#how">
                  {t("landing.how")}
                </a>
              </div>
              <p className="lp-note">{t("landing.note")}</p>
            </div>
            <div className="lp-visual" aria-hidden="true">
              <div className="bs-case">
                <section className="bs-shelf">
                  <p className="bs-shelf__plaque">{t("shelf.now")} · 3</p>
                  <div className="bs-caption lp-caption">
                    <span className="bs-caption__title">{PULLED}</span>
                    <span className="bs-caption__author">Аркадий и Борис Стругацкие</span>
                    <span className="bs-status">
                      <FormatIcons formats={["audio", "ebook"]} />
                      {t("answer.read_and_listened")} · 2019, 2024
                    </span>
                  </div>
                  <ul className="bs-shelf__row lp-row--captioned">
                    <Spines books={NOW} />
                  </ul>
                  <div className="bs-shelf__plank" />
                </section>
                <section className="bs-shelf">
                  <p className="bs-shelf__plaque">2025 · 18</p>
                  <ul className="bs-shelf__row">
                    <Spines books={YEAR} />
                  </ul>
                  <div className="bs-shelf__plank" />
                </section>
              </div>
            </div>
          </div>
        </section>

        <section id="how" className="lp-band">
          <div className="lp-wrap lp-stack">
            <h2 className="lp-h2">{t("landing.how")}</h2>
            <ol className="lp-grid">
              {list<{ title: string; text: string }>("landing.steps").map((step, i) => (
                <li key={step.title} className="lp-item">
                  <span className="lp-step__n">{i + 1}</span>
                  <h3 className="lp-h3">{step.title}</h3>
                  <p className="lp-muted">{step.text}</p>
                </li>
              ))}
            </ol>
          </div>
        </section>

        <section className="lp-wrap lp-feature lp-feature--first">
          <div className="lp-row">
            <div className="lp-text">
              <h2 className="lp-h2">{t("landing.readTitle")}</h2>
              <p className="lp-lead">{t("landing.readLead")}</p>
            </div>
            <div className="lp-visual lp-visual--narrow lp-cards">
              <div className="lp-card">
                <span className="lp-card__from">{t("landing.fromLitres")}</span>
                <span className="bs-answer lp-answer">
                  <span className="bs-answer__title">Солярис</span>
                  <span className="bs-status bs-status--strong">
                    <Ico name="audio" />
                    {t("landing.listenedOn")}
                  </span>
                </span>
              </div>
              <div className="lp-card">
                <span className="lp-card__from">{t("landing.fromAmazon")}</span>
                <span className="bs-answer lp-answer">
                  <span className="bs-answer__title">Klara and the Sun</span>
                  <span>{t("answer.not_found")}</span>
                  <span className="bs-answer__actions">
                    <span className="bs-btn bs-btn--secondary bs-btn--sm">
                      <Ico name="want" />
                      {t("search.want")}
                    </span>
                    <span className="bs-btn bs-btn--secondary bs-btn--sm">{t("search.read")}</span>
                    <span className="bs-btn bs-btn--secondary bs-btn--sm">{t("search.listened")}</span>
                  </span>
                </span>
              </div>
            </div>
          </div>
        </section>

        <section className="lp-wrap lp-feature">
          <div className="lp-row lp-row--reverse">
            <div className="lp-text">
              <h2 className="lp-h2">{t("stats.title")}</h2>
              <p className="lp-lead">{t("landing.yearLead")}</p>
            </div>
            <div className="lp-visual lp-visual--year">
              <div className="bs-year">
                <p className="bs-year__sum">
                  {t("stats.total", { year: 2025, count: 18 })} · {t("stats.listened", { count: 11 })} · {t("stats.read", { count: 7 })}
                </p>
                <div aria-hidden="true">
                  <div className="bs-year__months">
                    {MONTHS.map((books, m) =>
                      books.length ? (
                        <span className="bs-stack" key={m}>
                          {books.map(([cloth, format], i) => (
                            <span className={`bs-stack__book bs-cloth--${cloth}`} key={i}>
                              <Ico name={format} />
                            </span>
                          ))}
                        </span>
                      ) : (
                        <span key={m} />
                      ),
                    )}
                  </div>
                  <div className="bs-year__labels">
                    {MONTHS.map((_, m) => (
                      <span key={m}>{monthLabel(lng, m)}</span>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="lp-wrap lp-feature lp-feature--last">
          <div className="lp-row">
            <div className="lp-text">
              <h2 className="lp-h2">{t("landing.assistantTitle")}</h2>
              <p className="lp-lead">{t("landing.assistantLead")}</p>
            </div>
            <div className="lp-visual lp-visual--narrow lp-chat">
              {list<string>("landing.chat").map((line, i) => (
                <p key={i} className={i % 2 ? "lp-bubble lp-bubble--reply" : "lp-bubble"}>
                  {line}
                </p>
              ))}
            </div>
          </div>
        </section>

        <section className="lp-band">
          <div className="lp-wrap lp-stack lp-stack--own">
            <h2 className="lp-h2">{t("landing.ownTitle")}</h2>
            <dl className="lp-grid">
              {list<{ title: string; text: string }>("landing.own").map((item) => (
                <div key={item.title} className="lp-item lp-item--ruled">
                  <dt className="lp-item__title">{item.title}</dt>
                  <dd className="lp-muted">{item.text}</dd>
                </div>
              ))}
            </dl>
          </div>
        </section>

        <section id="faq" className="lp-wrap lp-faq">
          <h2 className="lp-h2">{t("landing.faq")}</h2>
          <div>
            {list<{ q: string; a: string }>("landing.questions").map((item, i) => (
              <details key={item.q} open={i === 0}>
                <summary>{item.q}</summary>
                <p>{item.a}</p>
              </details>
            ))}
          </div>
        </section>

        <section className="lp-wrap lp-final">
          <div className="lp-cta">
            <div className="lp-cta__text">
              <h2 className="lp-h2 lp-h2--small">{t("landing.ctaTitle")}</h2>
              <p className="lp-muted">{t("landing.ctaLead")}</p>
            </div>
            {create}
          </div>
        </section>
      </main>

      <div className="lp-wrap">
        <footer className="bs-footer lp-footer">
          <span>{t("footer.tagline")}</span>
          <a href={SOURCE_URL} target="_blank" rel="noreferrer">{t("footer.source")}</a>
        </footer>
      </div>
    </div>
  )
}
