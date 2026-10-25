import { lazy, Suspense, useEffect, type ComponentType } from "react"
import { useTranslation } from "react-i18next"
import { Link, Navigate, Outlet, Route, Routes, useLocation } from "react-router-dom"
import { RouteBoundary } from "@/components/RouteBoundary"
import { TabBar } from "@/components/TabBar"
import { oauthReturnTo, rememberReturnTo, takeReturnTo } from "@/lib/returnTo"
import { ShelfProvider } from "@/lib/shelf"
import { SessionProvider, useSession } from "@/lib/session"
import type { User } from "@/lib/types"
import { useMediaQuery } from "@/lib/useMediaQuery"
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
const profile = () => import("@/screens/ProfileScreen")
const ProfileScreen = lazyScreen(profile, "ProfileScreen")
const DeletedScreen = lazyScreen(profile, "DeletedScreen")
const sources = () => import("@/screens/SourcesScreen")
const SourcesScreen = lazyScreen(sources, "SourcesScreen")
const LitresScreen = lazyScreen(sources, "LitresScreen")
const KindleExportScreen = lazyScreen(sources, "KindleExportScreen")
const StatsScreen = lazyScreen(() => import("@/screens/StatsScreen"), "StatsScreen")
const ShareScreen = lazyScreen(() => import("@/screens/ShareScreen"), "ShareScreen")
const RemoteBrowserScreen = lazyScreen(() => import("@/screens/RemoteBrowserScreen"), "RemoteBrowserScreen")

function RequireUser() {
  const { user } = useSession()
  const location = useLocation()
  if (user === undefined) return null
  if (!user) return <Navigate to="/login" replace state={{ from: location }} />
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
  const { pathname } = useLocation()
  return (
    <div className="app">
      <header className="bs-header">
        <span className="bs-wordmark">{t("app.name")}</span>
        {desktop && <TabBar top />}
        <Link to="/profile" className="bs-avatar" aria-label={t("profile.title")}>
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
              <Route path="/sources/litres/captcha" element={<RemoteBrowserScreen purpose="litres" />} />
              <Route element={<Shell />}>
                <Route path="/" element={<BookcaseScreen />} />
                <Route path="/stats" element={<StatsScreen />} />
                <Route path="/sources" element={<SourcesScreen />} />
                <Route path="/sources/litres" element={<LitresScreen />} />
                <Route path="/sources/kindle-export" element={<KindleExportScreen />} />
                <Route path="/profile" element={<ProfileScreen />} />
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
