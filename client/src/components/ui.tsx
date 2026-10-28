import { useEffect, useId, useMemo, useRef, useState, type InputHTMLAttributes, type ReactNode } from "react"
import { useTranslation } from "react-i18next"
import type { ShelfKey } from "@/lib/types"

export function ShelfEnd({
  shelfKey,
  horizontal,
  onMore,
}: {
  shelfKey: ShelfKey
  horizontal?: boolean
  onMore: (key: ShelfKey) => void
}) {
  const ref = useRef<HTMLLIElement>(null)
  useEffect(() => {
    const el = ref.current
    if (!el || typeof IntersectionObserver === "undefined") return
    const observer = new IntersectionObserver((entries) => entries.some((e) => e.isIntersecting) && onMore(shelfKey), {
      root: horizontal ? el.parentElement : null,
      rootMargin: horizontal ? "0px 240px 0px 0px" : "0px 0px 240px 0px",
    })
    observer.observe(el)
    return () => observer.disconnect()
  }, [shelfKey, horizontal, onMore])
  return <li ref={ref} className="bs-shelf__end" aria-hidden="true" />
}

export type IconName = "audio" | "ebook" | "want" | "owned" | "progress" | "done" | "search" | "close" | "pen"

export const Ico = ({ name }: { name: IconName }) => <i className={`bs-ico bs-ico-${name}`} aria-hidden="true" />

export function FormatIcons({ formats }: { formats: ("audio" | "ebook")[] }) {
  return (
    <span className="bs-status__formats">
      {formats.map((f) => (
        <Ico key={f} name={f} />
      ))}
    </span>
  )
}

const STATUS_ICON = { want: "want", owned: "owned", in_progress: "progress", done: "done" } as const

export function StatusMark({
  text,
  status,
  formats,
  strong,
}: {
  text: string
  status?: keyof typeof STATUS_ICON
  formats?: ("audio" | "ebook")[]
  strong?: boolean
}) {
  return (
    <span className={strong ? "bs-status bs-status--strong" : "bs-status"}>
      {formats ? <FormatIcons formats={formats} /> : status && <Ico name={STATUS_ICON[status]} />}
      {text}
    </span>
  )
}

type FieldProps = InputHTMLAttributes<HTMLInputElement> & {
  label: string
  error?: ReactNode
  hint?: ReactNode
  hand?: boolean
}

export function Field({ label, error, hint, hand, className, ...input }: FieldProps) {
  const id = useId()
  const errorId = `${id}-error`
  return (
    <div className="bs-field">
      <label className="bs-field__label" htmlFor={id}>
        {label}
      </label>
      <input
        id={id}
        className={`bs-field__input${hand ? "" : " bs-field__input--plain"}${className ? ` ${className}` : ""}`}
        aria-invalid={error ? true : undefined}
        aria-describedby={error ? errorId : undefined}
        {...input}
      />
      {error && (
        <span className="bs-field__error" id={errorId}>
          {error}
        </span>
      )}
      {hint && !error && <span className="bs-field__hint">{hint}</span>}
    </div>
  )
}

const monthKey = (year: number, month: number) => `${year}-${String(month + 1).padStart(2, "0")}`

type MonthFieldProps = { label: string; value: string; onChange: (value: string) => void; disabled?: boolean }

export function MonthField({ label, value, onChange, disabled }: MonthFieldProps) {
  const { t, i18n } = useTranslation()
  const id = useId()
  const box = useRef<HTMLDivElement>(null)
  const trigger = useRef<HTMLButtonElement>(null)
  const [open, setOpen] = useState(false)
  const now = new Date()
  const [year, setYear] = useState(now.getFullYear())
  const names = useMemo(() => {
    const short = new Intl.DateTimeFormat(i18n.language, { month: "short" })
    return Array.from({ length: 12 }, (_, m) => short.format(new Date(2000, m, 1)))
  }, [i18n.language])
  const shown = value
    ? new Intl.DateTimeFormat(i18n.language, { month: "long", year: "numeric" }).format(
        new Date(Number(value.slice(0, 4)), Number(value.slice(5, 7)) - 1, 1),
      )
    : ""

  useEffect(() => {
    if (!open) return
    const away = (e: PointerEvent) => {
      if (!box.current?.contains(e.target as Node)) setOpen(false)
    }
    window.addEventListener("pointerdown", away)
    return () => window.removeEventListener("pointerdown", away)
  }, [open])

  const close = () => {
    setOpen(false)
    trigger.current?.focus()
  }
  const pick = (next: string) => {
    close()
    if (next !== value) onChange(next)
  }

  return (
    <div
      className="bs-field bs-month"
      ref={box}
      data-open={open || undefined}
      onKeyDown={(e) => {
        if (!open || e.key !== "Escape") return
        e.stopPropagation()
        close()
      }}
    >
      <label className="bs-field__label" htmlFor={id}>
        {label}
      </label>
      <button
        id={id}
        ref={trigger}
        type="button"
        className="bs-field__input bs-month__value"
        aria-expanded={open}
        disabled={disabled}
        onClick={() => {
          setYear(Number(value.slice(0, 4)) || now.getFullYear())
          setOpen(!open)
        }}
      >
        {shown || "\u00a0"}
      </button>
      {open && (
        <div className="bs-month__panel" role="dialog" aria-label={label}>
          <div className="bs-month__year">
            <button type="button" className="bs-iconbtn" aria-label={t("entry.prevYear")} onClick={() => setYear(year - 1)}>
              ‹
            </button>
            <span>{year}</span>
            <button
              type="button"
              className="bs-iconbtn"
              aria-label={t("entry.nextYear")}
              disabled={year >= now.getFullYear()}
              onClick={() => setYear(year + 1)}
            >
              ›
            </button>
          </div>
          <div className="bs-month__grid">
            {names.map((name, m) => (
              <button
                key={name}
                type="button"
                aria-pressed={monthKey(year, m) === value}
                disabled={new Date(year, m, 1) > now}
                onClick={() => pick(monthKey(year, m))}
              >
                {name}
              </button>
            ))}
          </div>
          <div className="bs-month__actions">
            <button type="button" className="bs-btn bs-btn--quiet bs-btn--sm" onClick={() => pick("")}>
              {t("entry.clearMonth")}
            </button>
            <button
              type="button"
              className="bs-btn bs-btn--quiet bs-btn--sm"
              onClick={() => pick(monthKey(now.getFullYear(), now.getMonth()))}
            >
              {t("entry.thisMonth")}
            </button>
          </div>
        </div>
      )}
    </div>
  )
}

export function Choices<T extends string>({
  legend,
  value,
  options,
  onChange,
  hideLegend,
  disabled,
}: {
  legend: string
  value: T
  options: { value: T; label: string; icon?: IconName; lang?: string }[]
  onChange: (value: T) => void
  hideLegend?: boolean
  disabled?: boolean
}) {
  const name = useId()
  return (
    <fieldset className="bs-choices" disabled={disabled}>
      <legend className={hideLegend ? "bs-sr" : undefined}>{legend}</legend>
      {options.map((o) => (
        <label key={o.value} className="bs-choice" lang={o.lang}>
          <input type="radio" name={name} checked={value === o.value} onChange={() => onChange(o.value)} />
          <span>
            {o.icon && <Ico name={o.icon} />}
            {o.label}
          </span>
        </label>
      ))}
    </fieldset>
  )
}

export const SourceLink = () => (
  <a className="bs-repo" href="https://github.com/AlexKlim/bshelf" target="_blank" rel="noreferrer" aria-label="GitHub">
    <svg viewBox="0 0 16 16" aria-hidden="true">
      <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0 0 16 8c0-4.42-3.58-8-8-8z" />
    </svg>
  </a>
)

export function LangSwitch() {
  const { t, i18n } = useTranslation()
  const current = i18n.resolvedLanguage ?? i18n.language
  return (
    <div className="bs-lang" role="group" aria-label={t("lang.label")}>
      {(["ru", "en"] as const).map((lng) => (
        <button key={lng} type="button" lang={lng} aria-pressed={current === lng} onClick={() => i18n.changeLanguage(lng)}>
          {lng.toUpperCase()}
        </button>
      ))}
    </div>
  )
}
