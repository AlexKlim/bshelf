import { Component, type ReactNode } from "react"
import i18n from "@/i18n"
import { isChunkError, page, reloadOnce } from "@/lib/chunks"

export class RouteBoundary extends Component<{ children: ReactNode }, { failed: boolean; reloading: boolean }> {
  state = { failed: false, reloading: false }

  static getDerivedStateFromError() {
    return { failed: true }
  }

  componentDidCatch(error: unknown) {
    if (isChunkError(error) && reloadOnce()) this.setState({ reloading: true })
  }

  render() {
    if (this.state.reloading) return null
    if (!this.state.failed) return this.props.children
    return (
      <p className="bs-retry">
        {i18n.t("app.screenError")}
        <button type="button" className="bs-btn bs-btn--quiet" onClick={() => page.reload()}>
          {i18n.t("book.retry")}
        </button>
      </p>
    )
  }
}
