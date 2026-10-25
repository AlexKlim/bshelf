import { useEffect, useId, useRef, type InputHTMLAttributes, type ReactNode } from "react"
import type { ShelfKey } from "@/lib/types"

// Keyed by the number of loaded books by the caller, so it observes afresh after each page.
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
  options: { value: T; label: string; icon?: IconName }[]
  onChange: (value: T) => void
  hideLegend?: boolean
  disabled?: boolean
}) {
  const name = useId()
  return (
    <fieldset className="bs-choices" disabled={disabled}>
      <legend className={hideLegend ? "bs-sr" : undefined}>{legend}</legend>
      {options.map((o) => (
        <label key={o.value} className="bs-choice">
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
