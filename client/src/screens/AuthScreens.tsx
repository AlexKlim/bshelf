import { useEffect, useRef, useState, type FormEvent, type ReactNode } from "react"
import { useTranslation } from "react-i18next"
import { Link, useNavigate, useSearchParams } from "react-router-dom"
import {
  confirmEmail,
  register,
  requestPasswordReset,
  resendConfirmation,
  resetPassword,
  signIn,
} from "@/api"
import { Field } from "@/components/ui"
import type { ApiError } from "@/lib/api"
import { useSession } from "@/lib/session"
import { errorMessage } from "@/lib/vocab"

type Errors = Record<string, string>

function useFieldErrors(fallback: string) {
  const { t } = useTranslation()
  const [errors, setErrors] = useState<Errors>({})
  const fromApi = (e: unknown) => {
    const error = e as ApiError
    const next: Errors = {}
    for (const item of error.errors ?? [{ code: "generic" }]) {
      const field = item.field && item.field !== "confirmation_token" && item.field !== "reset_password_token" ? item.field : fallback
      next[field] ??= errorMessage(t, item)
    }
    setErrors(next)
  }
  return { errors, setErrors, fromApi }
}

function AuthPage({ title, lead, children }: { title: string; lead?: ReactNode; children: ReactNode }) {
  const { t } = useTranslation()
  return (
    <main className="bs-auth">
      <p className="bs-wordmark bs-auth__mark">{t("app.name")}</p>
      <section className="bs-entry bs-auth__sheet" aria-labelledby="auth-title">
        <h1 className="bs-entry__title" id="auth-title">
          {title}
        </h1>
        {lead && <p className="bs-auth__lead">{lead}</p>}
        {children}
      </section>
    </main>
  )
}

function useBusy() {
  const [busy, setBusy] = useState(false)
  const run = async (fn: () => Promise<void>) => {
    setBusy(true)
    try {
      await fn()
    } finally {
      setBusy(false)
    }
  }
  return [busy, run] as const
}

export function LoginScreen() {
  const { t } = useTranslation()
  const { setUser } = useSession()
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")
  const { errors, setErrors, fromApi } = useFieldErrors("password")
  const [busy, run] = useBusy()
  const unconfirmed = errors.email === t("errors.unconfirmed")

  const submit = (e: FormEvent) => {
    e.preventDefault()
    if (!email || !password) return setErrors({ ...(!email && { email: t("errors.blank") }), ...(!password && { password: t("errors.blank") }) })
    run(async () => {
      try {
        const { user } = await signIn(email, password)
        setUser(user)
      } catch (err) {
        const code = (err as ApiError).code
        if (code === "unconfirmed") setErrors({ email: t("errors.unconfirmed") })
        else fromApi(err)
      }
    })
  }

  return (
    <AuthPage title={t("auth.signInTitle")}>
      <form className="bs-auth__form" onSubmit={submit} noValidate>
        <Field label={t("auth.email")} type="email" autoComplete="email" value={email} error={errors.email} onChange={(e) => setEmail(e.target.value)} />
        {unconfirmed && <ResendLink email={email} />}
        <Field
          label={t("auth.password")}
          type="password"
          autoComplete="current-password"
          value={password}
          error={errors.password}
          onChange={(e) => setPassword(e.target.value)}
        />
        <div className="bs-auth__actions">
          <button type="submit" className="bs-btn bs-btn--primary" aria-busy={busy} disabled={busy}>
            {busy ? t("auth.signingIn") : t("auth.signIn")}
          </button>
          <Link className="bs-btn bs-btn--quiet" to="/forgot-password">
            {t("auth.forgot")}
          </Link>
        </div>
      </form>
      <p className="bs-auth__switch">
        {t("auth.noAccount")} <Link to="/register">{t("auth.register")}</Link>
      </p>
    </AuthPage>
  )
}

function ResendLink({ email }: { email: string }) {
  const { t } = useTranslation()
  const [sent, setSent] = useState(false)
  if (sent) return <p className="bs-field__hint">{t("auth.resent")}</p>
  return (
    <button type="button" className="bs-btn bs-btn--quiet bs-btn--sm bs-auth__inline" onClick={() => resendConfirmation(email).then(() => setSent(true), () => setSent(true))}>
      {t("auth.resend")}
    </button>
  )
}

export function RegisterScreen() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")
  const { errors, setErrors, fromApi } = useFieldErrors("email")
  const [busy, run] = useBusy()

  const submit = (e: FormEvent) => {
    e.preventDefault()
    if (!email || !password) return setErrors({ ...(!email && { email: t("errors.blank") }), ...(!password && { password: t("errors.blank") }) })
    run(async () => {
      try {
        await register(email, password)
        navigate(`/check-email?email=${encodeURIComponent(email)}`)
      } catch (err) {
        fromApi(err)
      }
    })
  }

  return (
    <AuthPage title={t("auth.registerTitle")} lead={t("auth.registerLead")}>
      <form className="bs-auth__form" onSubmit={submit} noValidate>
        <Field label={t("auth.email")} type="email" autoComplete="email" value={email} error={errors.email} onChange={(e) => setEmail(e.target.value)} />
        <Field
          label={t("auth.password")}
          type="password"
          autoComplete="new-password"
          value={password}
          error={errors.password}
          hint={t("auth.passwordHint")}
          onChange={(e) => setPassword(e.target.value)}
        />
        <div className="bs-auth__actions">
          <button type="submit" className="bs-btn bs-btn--primary" aria-busy={busy} disabled={busy}>
            {busy ? t("auth.registering") : t("auth.register")}
          </button>
        </div>
      </form>
      <p className="bs-auth__switch">
        {t("auth.haveAccount")} <Link to="/login">{t("auth.signIn")}</Link>
      </p>
    </AuthPage>
  )
}

export function CheckEmailScreen() {
  const { t } = useTranslation()
  const [params] = useSearchParams()
  const email = params.get("email") ?? ""
  return (
    <AuthPage title={t("auth.checkTitle")} lead={email ? t("auth.checkLead", { email }) : t("auth.checkLeadNoEmail")}>
      <div className="bs-auth__actions">
        {email && <ResendLink email={email} />}
        <Link className="bs-btn bs-btn--quiet" to="/login">
          {t("auth.signIn")}
        </Link>
      </div>
    </AuthPage>
  )
}

export function ConfirmScreen() {
  const { t } = useTranslation()
  const [params] = useSearchParams()
  const token = params.get("token") ?? ""
  const [state, setState] = useState<"working" | "done" | "error">("working")
  const [code, setCode] = useState("")
  const sent = useRef(false)

  useEffect(() => {
    if (sent.current) return
    sent.current = true
    confirmEmail(token).then(
      () => setState("done"),
      (e: ApiError) => {
        setCode(e.code)
        setState(e.code === "already_confirmed" ? "done" : "error")
      },
    )
  }, [token])

  if (state === "working") return <AuthPage title={t("auth.confirming")}>{null}</AuthPage>
  if (state === "done") {
    return (
      <AuthPage title={t("auth.confirmedTitle")} lead={t(code === "already_confirmed" ? "errors.already_confirmed" : "auth.confirmedLead")}>
        <div className="bs-auth__actions">
          <Link className="bs-btn bs-btn--primary" to="/login">
            {t("auth.signIn")}
          </Link>
        </div>
      </AuthPage>
    )
  }
  return (
    <AuthPage title={t("auth.confirmFailed")} lead={errorMessage(t, { code })}>
      <div className="bs-auth__actions">
        <Link className="bs-btn bs-btn--quiet" to="/login">
          {t("auth.signIn")}
        </Link>
      </div>
    </AuthPage>
  )
}

export function ForgotPasswordScreen() {
  const { t } = useTranslation()
  const [email, setEmail] = useState("")
  const [sent, setSent] = useState(false)
  const { errors, setErrors, fromApi } = useFieldErrors("email")
  const [busy, run] = useBusy()

  if (sent) {
    return (
      <AuthPage title={t("auth.checkTitle")} lead={t("auth.resetSent", { email })}>
        <Link className="bs-btn bs-btn--quiet" to="/login">
          {t("auth.signIn")}
        </Link>
      </AuthPage>
    )
  }

  const submit = (e: FormEvent) => {
    e.preventDefault()
    if (!email) return setErrors({ email: t("errors.blank") })
    run(() => requestPasswordReset(email).then(() => setSent(true), fromApi))
  }

  return (
    <AuthPage title={t("auth.forgotTitle")} lead={t("auth.forgotLead")}>
      <form className="bs-auth__form" onSubmit={submit} noValidate>
        <Field label={t("auth.email")} type="email" autoComplete="email" value={email} error={errors.email} onChange={(e) => setEmail(e.target.value)} />
        <div className="bs-auth__actions">
          <button type="submit" className="bs-btn bs-btn--primary" aria-busy={busy} disabled={busy}>
            {t("auth.sendLink")}
          </button>
          <Link className="bs-btn bs-btn--quiet" to="/login">
            {t("common.cancel")}
          </Link>
        </div>
      </form>
    </AuthPage>
  )
}

export function ResetPasswordScreen() {
  const { t } = useTranslation()
  const [params] = useSearchParams()
  const [password, setPassword] = useState("")
  const [done, setDone] = useState(false)
  const [badToken, setBadToken] = useState(false)
  const { errors, setErrors, fromApi } = useFieldErrors("password")
  const [busy, run] = useBusy()

  if (done) {
    return (
      <AuthPage title={t("auth.passwordChanged")}>
        <div className="bs-auth__actions">
          <Link className="bs-btn bs-btn--primary" to="/login">
            {t("auth.signIn")}
          </Link>
        </div>
      </AuthPage>
    )
  }

  const submit = (e: FormEvent) => {
    e.preventDefault()
    if (!password) return setErrors({ password: t("errors.blank") })
    run(() =>
      resetPassword(params.get("token") ?? "", password).then(
        () => setDone(true),
        (err: ApiError) => {
          fromApi(err)
          setBadToken(err.errors.some((item) => item.field === "reset_password_token"))
        },
      ),
    )
  }

  return (
    <AuthPage title={t("auth.resetTitle")}>
      <form className="bs-auth__form" onSubmit={submit} noValidate>
        <Field
          label={t("auth.newPassword")}
          type="password"
          autoComplete="new-password"
          value={password}
          error={errors.password}
          hint={t("auth.passwordHint")}
          onChange={(e) => setPassword(e.target.value)}
        />
        {badToken && (
          <Link className="bs-btn bs-btn--quiet bs-btn--sm bs-auth__inline" to="/forgot-password">
            {t("auth.requestNew")}
          </Link>
        )}
        <div className="bs-auth__actions">
          <button type="submit" className="bs-btn bs-btn--primary" aria-busy={busy} disabled={busy}>
            {t("auth.savePassword")}
          </button>
        </div>
      </form>
    </AuthPage>
  )
}
