import { useEffect, useState, type FormEvent } from "react"
import { useTranslation } from "react-i18next"
import { Link, useNavigate } from "react-router-dom"
import { createToken, deleteAccount, getAssistants, listTokens, revokeAssistant, revokeToken, signOut } from "@/api"
import { Choices, Field } from "@/components/ui"
import { useSession } from "@/lib/session"
import type { ApiToken, Assistant } from "@/lib/types"
import { useOnline } from "@/lib/useOnline"
import { errorMessage } from "@/lib/vocab"

const SHORTCUT_URL = import.meta.env.VITE_SHORTCUT_URL as string | undefined

function useDate() {
  const { i18n } = useTranslation()
  return (iso: string) => new Intl.DateTimeFormat(i18n.language, { day: "numeric", month: "long", year: "numeric" }).format(new Date(iso))
}

export function ProfileScreen() {
  const { t, i18n } = useTranslation()
  const { user, setUser } = useSession()
  const navigate = useNavigate()

  return (
    <div className="bs-screen bs-screen--sheet">
      <h1 className="bs-screen__title">{t("profile.title")}</h1>
      <p className="bs-source__meta">{user?.email}</p>
      <Shortcut />
      <Assistants />
      <section className="bs-screen__section" aria-labelledby="lang-title">
        <h2 className="bs-screen__h" id="lang-title">
          {t("profile.language")}
        </h2>
        <Choices
          legend={t("profile.language")}
          hideLegend
          value={i18n.language.startsWith("ru") ? "ru" : "en"}
          onChange={(lng) => i18n.changeLanguage(lng)}
          options={[
            { value: "en", label: "English", lang: "en" },
            { value: "ru", label: "Русский", lang: "ru" },
          ]}
        />
      </section>
      <section className="bs-screen__section bs-screen__section--start">
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
      </section>
      <DeleteAccount />
    </div>
  )
}

function Shortcut() {
  const { t } = useTranslation()
  const date = useDate()
  const online = useOnline()
  const [tokens, setTokens] = useState<ApiToken[]>([])
  const [fresh, setFresh] = useState<string | null>(null)
  const [copied, setCopied] = useState(false)
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
      setCopied(false)
    } catch (e) {
      setError(errorMessage(t, e))
    }
  }

  const copy = async () => {
    if (!fresh) return
    try {
      await navigator.clipboard.writeText(fresh)
      setCopied(true)
    } catch {
      setCopied(false)
    }
  }

  return (
    <section className="bs-screen__section" aria-labelledby="shortcut-title">
      <h2 className="bs-screen__h" id="shortcut-title">
        {t("profile.shortcut")}
      </h2>
      <p className="bs-session__text">{t("profile.shortcutLead")}</p>
      {fresh ? (
        <div className="bs-token">
          <code className="bs-token__value">{fresh}</code>
          <p className="bs-path__note">{t("profile.tokenOnce")}</p>
          <div className="bs-auth__actions">
            <button type="button" className="bs-btn bs-btn--primary" onClick={copy}>
              {copied ? t("profile.copied") : t("profile.copy")}
            </button>
            {SHORTCUT_URL && (
              <a className="bs-btn bs-btn--quiet" href={SHORTCUT_URL} target="_blank" rel="noreferrer">
                {t("profile.installShortcut")}
              </a>
            )}
          </div>
        </div>
      ) : (
        <div>
          <button type="button" className="bs-btn bs-btn--secondary" disabled={!online} onClick={create}>
            {t("profile.createToken")}
          </button>
        </div>
      )}
      {error && <p className="bs-field__error">{error}</p>}
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
            className="bs-btn bs-btn--quiet"
            disabled={!online}
            onClick={() => revokeToken(token.id).then(() => setTokens(tokens.filter((x) => x.id !== token.id)))}
          >
            {t("profile.revoke")}
          </button>
        </div>
      ))}
    </section>
  )
}

function Assistants() {
  const { t } = useTranslation()
  const date = useDate()
  const online = useOnline()
  const [items, setItems] = useState<Assistant[] | null>(null)
  const [failed, setFailed] = useState(false)

  useEffect(() => {
    getAssistants().then(
      (r) => setItems(r.assistants),
      () => setFailed(true),
    )
  }, [])

  return (
    <section className="bs-screen__section" aria-labelledby="assistants-title">
      <h2 className="bs-screen__h" id="assistants-title">
        {t("profile.assistants")}
      </h2>
      {failed && <p className="bs-source__meta">{t("profile.assistantsUnavailable")}</p>}
      {items?.length === 0 && (
        <p className="bs-source__meta">
          {t("profile.noAssistants")} {t("profile.connectHint", { url: `${window.location.origin}/mcp` })}
        </p>
      )}
      {items?.map((a) => (
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
            className="bs-btn bs-btn--quiet"
            disabled={!online}
            onClick={() => revokeAssistant(a.id).then(() => setItems(items.filter((x) => x.id !== a.id)))}
          >
            {t("profile.revoke")}
          </button>
        </div>
      ))}
    </section>
  )
}

function DeleteAccount() {
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
    <section className="bs-screen__section" aria-labelledby="delete-title">
      <h2 className="bs-screen__h" id="delete-title">
        {t("profile.deleteTitle")}
      </h2>
      <p className="bs-session__text">{t("profile.deleteLead")}</p>
      <form className="bs-auth__form" onSubmit={submit} noValidate>
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
    </section>
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
