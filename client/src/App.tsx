import { lazy, Suspense, useEffect, type ComponentType } from "react"
import { useTranslation } from "react-i18next"
import { Link, Navigate, Outlet, Route, Routes, useLocation } from "react-router-dom"
import { RouteBoundary } from "@/components/RouteBoundary"
import { LangSwitch, SourceLink } from "@/components/ui"
import { TabBar } from "@/components/TabBar"
import { oauthReturnTo, rememberReturnTo, takeReturnTo } from "@/lib/returnTo"
import { ShelfProvider } from "@/lib/shelf"
import { SessionProvider, useSession } from "@/lib/session"
import type { User } from "@/lib/types"
import { TABLET_UP, useMediaQuery } from "@/lib/useMediaQuery"
import { BookcaseScreen } from "@/screens/BookcaseScreen"

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function lazyScreen<M extends Record<K, ComponentType<any>>, K extends keyof M>(load: () => Promise<M>, name: K) {
  return lazy(() => load().then((m) => ({ default: m[name] })))
}

const auth = () => import("@/screens/AuthScreens")
const LoginScreen = lazyScreen(auth, "LoginScreen")
const RegisterScreen = lazyScreen(auth, "RegisterScreen")
const ForgotPasswordScreen = lazyScreen(auth, "ForgotPasswordScreen")
const CheckEmailScreen = lazyScreen(auth, "CheckEmailScreen")
const ConfirmScreen = lazyScreen(auth, "ConfirmScreen")
const ResetPasswordScreen = lazyScreen(auth, "ResetPasswordScreen")
const account = () => import("@/screens/AccountScreen")
const AccountScreen = lazyScreen(account, "AccountScreen")
const DeletedScreen = lazyScreen(account, "DeletedScreen")
const sources = () => import("@/screens/SourcesScreen")
const SourcesScreen = lazyScreen(sources, "SourcesScreen")
const StatsScreen = lazyScreen(() => import("@/screens/StatsScreen"), "StatsScreen")
const ShareScreen = lazyScreen(() => import("@/screens/ShareScreen"), "ShareScreen")
const RemoteBrowserScreen = lazyScreen(() => import("@/screens/RemoteBrowserScreen"), "RemoteBrowserScreen")
const LandingScreen = lazyScreen(() => import("@/screens/LandingScreen"), "LandingScreen")

function RequireUser() {
  const { user } = useSession()
  const location = useLocation()
  if (user === undefined) return null
  if (!user) return location.pathname === "/" ? <LandingScreen /> : <Navigate to="/login" replace state={{ from: location }} />
  return (
    <ShelfProvider key={user.id}>
      <Outlet />
    </ShelfProvider>
  )
}

function GuestOnly() {
  const { user } = useSession()
  const location = useLocation()
  const param = new URLSearchParams(location.search).get("return_to")

  useEffect(() => {
    if (user === null) rememberReturnTo(param)
    if (!user) return
    const target = takeReturnTo(param)
    if (target) window.location.assign(target)
  }, [user, param])

  if (user === undefined) return null
  if (user) {
    if (oauthReturnTo(param)) return null
    const from = (location.state as { from?: { pathname: string; search: string } } | null)?.from
    return <Navigate to={from ? `${from.pathname}${from.search}` : "/"} replace />
  }
  return <Outlet />
}

function Shell() {
  const { t } = useTranslation()
  const { user } = useSession()
  const desktop = useMediaQuery("(min-width: 1200px)")
  const tablet = useMediaQuery(TABLET_UP)
  const { pathname } = useLocation()
  const inAccount = pathname.startsWith("/account")
  return (
    <div className="app">
      <header className="bs-header">
        {!tablet && /^\/account\/./.test(pathname) ? (
          <Link to="/account" className="bs-btn bs-btn--quiet app__back">
            {t("account.back")}
          </Link>
        ) : (
          <Link to="/" className="bs-wordmark">
            {t("app.name")}
          </Link>
        )}
        {desktop && <TabBar top />}
        <Link to="/account" className="bs-avatar" aria-label={t("account.title")} aria-current={inAccount ? "page" : undefined}>
          {user?.email[0]?.toUpperCase()}
        </Link>
      </header>
      <main className="app__main">
        <RouteBoundary key={pathname}>
          <Suspense fallback={null}>
            <Outlet />
          </Suspense>
        </RouteBoundary>
      </main>
      <div className="app__foot">
        <footer className="bs-footer">
          <span>{t("footer.tagline")}</span>
          <span className="bs-footer__end">
            <SourceLink />
            <LangSwitch />
          </span>
        </footer>
      </div>
      {!desktop && (
        <div className="app__tabs">
          <TabBar />
        </div>
      )}
    </div>
  )
}

export default function App({ initialUser }: { initialUser?: User | null }) {
  return (
    <SessionProvider initialUser={initialUser}>
      <RouteBoundary>
        <Suspense fallback={null}>
          <Routes>
            <Route element={<GuestOnly />}>
              <Route path="/login" element={<LoginScreen />} />
              <Route path="/register" element={<RegisterScreen />} />
              <Route path="/forgot-password" element={<ForgotPasswordScreen />} />
            </Route>
            <Route path="/check-email" element={<CheckEmailScreen />} />
            <Route path="/confirm" element={<ConfirmScreen />} />
            <Route path="/reset-password" element={<ResetPasswordScreen />} />
            <Route path="/deleted" element={<DeletedScreen />} />
            <Route element={<RequireUser />}>
              <Route path="/sources/kindle" element={<RemoteBrowserScreen purpose="kindle" />} />
              <Route path="/sources/litres" element={<RemoteBrowserScreen purpose="litres" />} />
              <Route path="/sources/storytel" element={<RemoteBrowserScreen purpose="storytel" />} />
              <Route element={<Shell />}>
                <Route path="/" element={<BookcaseScreen />} />
                <Route path="/stats" element={<StatsScreen />} />
                <Route path="/sources" element={<SourcesScreen />} />
                <Route path="/account/:section?" element={<AccountScreen />} />
                <Route path="/profile" element={<Navigate to="/account" replace />} />
                <Route path="/share" element={<ShareScreen />} />
              </Route>
            </Route>
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </Suspense>
      </RouteBoundary>
    </SessionProvider>
  )
}
