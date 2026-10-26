import { useEffect, useState, type FormEvent, type ReactNode } from "react"
import { useTranslation } from "react-i18next"
import { Link, Navigate, NavLink, useLocation, useNavigate, useParams } from "react-router-dom"
import {
  changePassword,
  createGeminiClient,
  createToken,
  deleteAccount,
  getAssistants,
  listTokens,
  revokeAssistant,
  revokeGeminiClient,
  revokeToken,
  signOut,
} from "@/api"
import { Choices, Field } from "@/components/ui"
import type { ApiError } from "@/lib/api"
import { useSession } from "@/lib/session"
import type { ApiToken } from "@/lib/types"
import { TABLET_UP, useMediaQuery } from "@/lib/useMediaQuery"
import { useOnline } from "@/lib/useOnline"
import { errorMessage } from "@/lib/vocab"
import "./AccountScreen.css"

const SHORTCUT_URL = import.meta.env.VITE_SHORTCUT_URL as string | undefined

const SECTIONS = ["profile", "shortcut", "assistants", "language", "delete"] as const
type Section = (typeof SECTIONS)[number]

const TITLE: Record<Section, string> = {
  profile: "account.profileTitle",
  shortcut: "profile.shortcut",
  assistants: "profile.assistants",
  language: "profile.language",
  delete: "profile.deleteTitle",
}
const LEAD: Partial<Record<Section, string>> = {
  shortcut: "profile.shortcutLead",
  assistants: "account.mcpLead",
  delete: "profile.deleteLead",
}

const LANGS = [
  { value: "ru", label: "Русский", lang: "ru" },
  { value: "en", label: "English", lang: "en" },
]

type Assistants = Awaited<ReturnType<typeof getAssistants>>

function useDate() {
  const { i18n } = useTranslation()
  return (iso: string) => new Intl.DateTimeFormat(i18n.language, { day: "numeric", month: "long", year: "numeric" }).format(new Date(iso))
}

function useLang() {
  const { i18n } = useTranslation()
  return i18n.language.startsWith("ru") ? "ru" : "en"
}

function Sub({ children }: { children: ReactNode }) {
  const H = useMediaQuery(TABLET_UP) ? "h3" : "h2"
  return <H className="mc-h2">{children}</H>
}

export function AccountScreen() {
  const { t } = useTranslation()
  const { section } = useParams()
  const { user } = useSession()
  const wide = useMediaQuery(TABLET_UP)

  if (section && !SECTIONS.includes(section as Section)) return <Navigate to="/account" replace />
  if (!section) return wide ? <Navigate to="/account/profile" replace /> : <AccountMenu />

  const body = <SectionBody section={section as Section} wide={wide} />
  if (!wide) return <div className="ac-page">{body}</div>
  return (
    <div className="ac-layout">
      <div className="ac-side">
        <div className="ac-head">
          <h1 className="ac-title">{t("account.title")}</h1>
          <p className="ac-email">{user?.email}</p>
        </div>
        <nav className="ac-nav" aria-label={t("account.sections")}>
          {SECTIONS.map((s) => (
            <NavLink key={s} to={`/account/${s}`} className={s === "delete" ? "ac-danger" : undefined}>
              {t(TITLE[s])}
            </NavLink>
          ))}
        </nav>
      </div>
      {body}
    </div>
  )
}

function AccountMenu() {
  const { t } = useTranslation()
  const { user } = useSession()
  const lang = useLang()
  const [connected, setConnected] = useState(0)

  useEffect(() => {
    getAssistants().then(
      (r) => setConnected(r.assistants.length),
      () => {},
    )
  }, [])

  const meta: Partial<Record<Section, string>> = {
    profile: t("account.profileMeta"),
    shortcut: t("account.shortcutMeta"),
    assistants: [t("account.assistantsMeta"), connected > 0 && t("account.connectedCount", { count: connected })]
      .filter(Boolean)
      .join(" · "),
    language: LANGS.find((l) => l.value === lang)?.label,
  }

  return (
    <div className="ac-menu">
      <div className="ac-head">
        <h1 className="ac-title">{t("account.title")}</h1>
        <p className="ac-email">{user?.email}</p>
      </div>
      <nav className="ac-list" aria-label={t("account.sections")}>
        {SECTIONS.map((s) => (
          <Link key={s} to={`/account/${s}`} className={s === "delete" ? "ac-item ac-danger" : "ac-item"}>
            <span className="ac-item__body">
              <span className="ac-item__title">{t(TITLE[s])}</span>
              {meta[s] && <span className="ac-item__meta">{meta[s]}</span>}
            </span>
            <span className="ac-chev" aria-hidden="true" />
          </Link>
        ))}
      </nav>
    </div>
  )
}

function SectionBody({ section, wide }: { section: Section; wide: boolean }) {
  const { t } = useTranslation()
  const Title = wide ? "h2" : "h1"
  const lead = LEAD[section]
  return (
    <section className="ac-section" aria-labelledby="ac-section-title">
      <div className="ac-section__head">
        <Title className="ac-title" id="ac-section-title">
          {t(TITLE[section])}
        </Title>
        {lead && <p className="mc-text">{t(lead)}</p>}
      </div>
      {section === "profile" && <ProfileSection />}
      {section === "shortcut" && <ShortcutSection />}
      {section === "assistants" && <AssistantsSection />}
      {section === "language" && <LanguageSection />}
      {section === "delete" && <DeleteSection />}
    </section>
  )
}

function ProfileSection() {
  const { t } = useTranslation()
  const { user, setUser } = useSession()
  const navigate = useNavigate()
  const online = useOnline()
  const [current, setCurrent] = useState("")
  const [password, setPassword] = useState("")
  const [errors, setErrors] = useState<{ current_password?: string; password?: string }>({})
  const [busy, setBusy] = useState(false)
  const [done, setDone] = useState(false)

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    setDone(false)
    const blank = { ...(!current && { current_password: t("errors.blank") }), ...(!password && { password: t("errors.blank") }) }
    if (!current || !password) return setErrors(blank)
    setBusy(true)
    try {
      await changePassword(current, password)
      setCurrent("")
      setPassword("")
      setErrors({})
      setDone(true)
    } catch (err) {
      const next: typeof errors = {}
      for (const item of (err as ApiError).errors ?? [{ code: "generic" }]) {
        if (item.field === "current_password") next.current_password ??= item.code === "invalid" ? t("account.wrongPassword") : errorMessage(t, item)
        else next.password ??= errorMessage(t, item)
      }
      setErrors(next)
    } finally {
      setBusy(false)
    }
  }

  return (
    <>
      <div className="ac-group">
        <Field label={t("auth.email")} value={user?.email ?? ""} readOnly />
      </div>
      <form className="ac-group ac-form" onSubmit={submit} noValidate>
        <Sub>{t("account.passwordTitle")}</Sub>
        <p className="mc-text mc-note">{t("account.passwordNote")}</p>
        <Field
          label={t("account.currentPassword")}
          type="password"
          autoComplete="current-password"
          value={current}
          error={errors.current_password}
          onChange={(e) => setCurrent(e.target.value)}
        />
        <Field
          label={t("auth.newPassword")}
          type="password"
          autoComplete="new-password"
          value={password}
          error={errors.password}
          hint={t("auth.passwordHint")}
          onChange={(e) => setPassword(e.target.value)}
        />
        <div className="bs-auth__actions">
          <button type="submit" className="bs-btn bs-btn--primary" disabled={busy || !online} aria-busy={busy}>
            {t("auth.savePassword")}
          </button>
          <span className="bs-path__note" role="status">
            {done && t("auth.passwordChanged")}
          </span>
        </div>
      </form>
      <div className="ac-group ac-group--start">
        <button
          type="button"
          className="bs-btn bs-btn--secondary"
          onClick={() =>
            signOut()
              .catch(() => {})
              .finally(() => {
                setUser(null)
                navigate("/login")
              })
          }
        >
          {t("profile.signOut")}
        </button>
      </div>
    </>
  )
}

function CopyValue({ value, label }: { value: string; label?: string }) {
  const { t } = useTranslation()
  const [copied, setCopied] = useState(false)
  const copy = () => navigator.clipboard.writeText(value).then(() => setCopied(true), () => setCopied(false))
  return (
    <div className="ac-copy">
      {label && <span className="ac-copy__label">{label}</span>}
      <div className="mc-url">
        <code>{value}</code>
        <button type="button" className="bs-btn bs-btn--secondary bs-btn--sm" onClick={copy}>
          {copied ? t("profile.copied") : t("account.copy")}
          {label && <span className="bs-sr"> {label}</span>}
        </button>
      </div>
    </div>
  )
}

function ShortcutSection() {
  const { t } = useTranslation()
  const date = useDate()
  const online = useOnline()
  const [tokens, setTokens] = useState<ApiToken[]>([])
  const [fresh, setFresh] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    listTokens().then(
      (r) => setTokens(r.api_tokens),
      () => {},
    )
  }, [])

  const create = async () => {
    setError(null)
    try {
      const { api_token, token } = await createToken(t("profile.shortcutTokenName"))
      setTokens([api_token, ...tokens])
      setFresh(token)
    } catch (e) {
      setError(errorMessage(t, e))
    }
  }

  return (
    <>
      <div className="ac-group ac-group--start">
        {fresh ? (
          <div className="bs-token ac-wide">
            <CopyValue value={fresh} />
            <p className="bs-path__note">{t("profile.tokenOnce")}</p>
            {SHORTCUT_URL && (
              <a className="bs-btn bs-btn--quiet" href={SHORTCUT_URL} target="_blank" rel="noreferrer">
                {t("profile.installShortcut")}
              </a>
            )}
          </div>
        ) : (
          <button type="button" className="bs-btn bs-btn--secondary" disabled={!online} onClick={create}>
            {t("profile.createToken")}
          </button>
        )}
        {error && <p className="bs-field__error">{error}</p>}
      </div>
      {tokens.length > 0 && (
        <div className="ac-group ac-group--tight">
          {tokens.map((token) => (
            <div className="bs-source" key={token.id}>
              <div className="bs-source__body">
                <span className="bs-source__name">{token.name}</span>
                <span className="bs-source__meta">
                  {token.last_used_at ? t("profile.lastUsed", { date: date(token.last_used_at) }) : t("profile.created", { date: date(token.created_at) })}
                </span>
              </div>
              <button
                type="button"
                className="bs-btn bs-btn--quiet bs-btn--sm"
                disabled={!online}
                onClick={() => revokeToken(token.id).then(() => setTokens(tokens.filter((x) => x.id !== token.id)))}
              >
                {t("profile.revoke")}
              </button>
            </div>
          ))}
        </div>
      )}
      <div className="ac-group">
        <Sub>iPhone</Sub>
        <ol className="bs-steps">
          {(t("account.iphoneSteps", { returnObjects: true }) as string[]).map((step) => (
            <li key={step}>{step}</li>
          ))}
        </ol>
      </div>
      <div className="ac-group">
        <Sub>Android</Sub>
        <p className="mc-text">{t("account.androidText")}</p>
      </div>
    </>
  )
}

type Kind = "claude" | "chatgpt" | "gemini"
const KINDS: { value: Kind; label: string }[] = [
  { value: "claude", label: "Claude" },
  { value: "chatgpt", label: "ChatGPT" },
  { value: "gemini", label: "Gemini" },
]
type Step = { title: string; text: string }

function Steps({ items, first }: { items: Step[]; first?: ReactNode }) {
  return (
    <ol className="mc-steps">
      {items.map((step, i) => (
        <li key={step.title}>
          <b>{step.title}</b>
          {step.text && <span className="mc-text">{step.text}</span>}
          {i === 0 && first}
        </li>
      ))}
    </ol>
  )
}

function AssistantsSection() {
  const { t } = useTranslation()
  const date = useDate()
  const online = useOnline()
  const navigate = useNavigate()
  const { hash } = useLocation()
  const kind = KINDS.find((k) => `#${k.value}` === hash) ?? KINDS[0]
  const [data, setData] = useState<Assistants | null>(null)
  const [failed, setFailed] = useState(false)

  const [version, setVersion] = useState(0)

  useEffect(() => {
    getAssistants().then(
      (r) => setData(r),
      () => setFailed(true),
    )
  }, [version])

  return (
    <>
      <div className="ac-group">
        <Sub>{t("account.mcpUrl")}</Sub>
        <CopyValue value={`${window.location.origin}/mcp`} />
      </div>
      <div className="ac-group ac-group--steps">
        <Choices
          legend={t("account.assistant")}
          hideLegend
          value={kind.value}
          options={KINDS}
          onChange={(value) => navigate({ hash: value === "claude" ? "" : value }, { replace: true })}
        />
        <Sub>{t("account.howTo", { name: kind.label })}</Sub>
        {kind.value === "gemini" ? (
          <>
            <p className="mc-text mc-note">{t("account.geminiFor")}</p>
            <Steps
              items={t("account.geminiSteps", { returnObjects: true }) as Step[]}
              first={<GeminiKey client={data?.gemini_client ?? null} onChange={() => setVersion((v) => v + 1)} />}
            />
          </>
        ) : (
          <Steps items={t(`account.${kind.value}Steps`, { returnObjects: true }) as Step[]} />
        )}
      </div>
      <div className="ac-group">
        <Sub>{t("account.askTitle")}</Sub>
        <ul className="mc-ask">
          {(t("account.ask", { returnObjects: true }) as string[]).map((q) => (
            <li key={q}>{q}</li>
          ))}
        </ul>
      </div>
      <div className="ac-group ac-group--tight">
        <Sub>{t("account.connectedTitle")}</Sub>
        {failed && <p className="mc-text">{t("profile.assistantsUnavailable")}</p>}
        {data?.assistants.length === 0 && <p className="mc-text">{t("profile.noAssistants")}</p>}
        {data?.assistants.map((a) => (
          <div className="bs-source" key={a.id}>
            <div className="bs-source__body">
              <span className="bs-source__name">{a.name}</span>
              <span className="bs-source__meta">
                {[t("profile.connected", { date: date(a.connected_at) }), a.last_active_at && t("profile.lastUsed", { date: date(a.last_active_at) })]
                  .filter(Boolean)
                  .join(" · ")}
              </span>
            </div>
            <button
              type="button"
              className="bs-btn bs-btn--quiet bs-btn--sm"
              disabled={!online}
              onClick={() =>
                revokeAssistant(a.id).then(() => setData((d) => d && { ...d, assistants: d.assistants.filter((x) => x.id !== a.id) }))
              }
            >
              {t("profile.revoke")}
            </button>
          </div>
        ))}
        {!!data?.assistants.length && <p className="mc-text mc-note">{t("account.revokeNote")}</p>}
      </div>
    </>
  )
}

function GeminiKey({ client, onChange }: { client: Assistants["gemini_client"]; onChange: () => void }) {
  const { t } = useTranslation()
  const date = useDate()
  const online = useOnline()
  const [fresh, setFresh] = useState<{ client_id: string; client_secret: string } | null>(null)
  const [error, setError] = useState<string | null>(null)
  const origin = window.location.origin

  const act = async (fn: () => Promise<unknown>) => {
    setError(null)
    try {
      await fn()
      onChange()
    } catch (e) {
      setError(errorMessage(t, e))
    }
  }
  const create = () => act(() => createGeminiClient().then(setFresh))
  const revoke = () => act(() => revokeGeminiClient().then(() => setFresh(null)))

  return (
    <div className="ac-key">
      {fresh ? (
        <div className="bs-token">
          <CopyValue label={t("account.clientId")} value={fresh.client_id} />
          <CopyValue label={t("account.clientSecret")} value={fresh.client_secret} />
          <p className="bs-path__note">{t("account.secretOnce")}</p>
        </div>
      ) : client ? (
        <>
          <p className="mc-text mc-note">{t("account.keyCreated", { date: date(client.created_at) })}</p>
          <CopyValue label={t("account.clientId")} value={client.client_id} />
        </>
      ) : null}
      <div className="bs-auth__actions">
        <button type="button" className="bs-btn bs-btn--secondary bs-btn--sm" disabled={!online} onClick={create}>
          {fresh || client ? t("account.newKey") : t("account.createKey")}
        </button>
        {(fresh || client) && (
          <button type="button" className="bs-btn bs-btn--quiet bs-btn--sm" disabled={!online} onClick={revoke}>
            {t("account.revokeKey")}
          </button>
        )}
      </div>
      {error && <p className="bs-field__error">{error}</p>}
      <CopyValue label={t("account.authUrl")} value={`${origin}/oauth/authorize`} />
      <CopyValue label={t("account.tokenUrl")} value={`${origin}/oauth/token`} />
    </div>
  )
}

function LanguageSection() {
  const { t, i18n } = useTranslation()
  return (
    <div className="ac-group">
      <Choices legend={t("profile.language")} hideLegend value={useLang()} onChange={(lng) => i18n.changeLanguage(lng)} options={LANGS} />
    </div>
  )
}

function DeleteSection() {
  const { t } = useTranslation()
  const { setUser } = useSession()
  const navigate = useNavigate()
  const online = useOnline()
  const [word, setWord] = useState("")
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const expected = t("profile.deleteWord")

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    if (word.trim().toLowerCase() !== expected) return setError(t("profile.deleteMismatch", { word: expected }))
    setBusy(true)
    try {
      await deleteAccount()
      setUser(null)
      navigate("/deleted", { replace: true })
    } catch (err) {
      setError(errorMessage(t, err))
      setBusy(false)
    }
  }

  return (
    <form className="ac-group ac-form" onSubmit={submit} noValidate>
      <Field
        label={t("profile.deleteLabel", { word: expected })}
        value={word}
        error={error}
        autoComplete="off"
        onChange={(e) => setWord(e.target.value)}
      />
      <div>
        <button type="submit" className="bs-btn bs-btn--secondary bs-btn--danger" disabled={busy || !online} aria-busy={busy}>
          {t("profile.deleteAction")}
        </button>
      </div>
    </form>
  )
}

export function DeletedScreen() {
  const { t } = useTranslation()
  return (
    <main className="bs-auth">
      <p className="bs-wordmark bs-auth__mark">{t("app.name")}</p>
      <section className="bs-entry bs-auth__sheet">
        <h1 className="bs-entry__title">{t("profile.deletedTitle")}</h1>
        <p className="bs-auth__lead">{t("profile.deletedLead")}</p>
        <div>
          <Link className="bs-btn bs-btn--quiet" to="/register">
            {t("auth.register")}
          </Link>
        </div>
      </section>
    </main>
  )
}
