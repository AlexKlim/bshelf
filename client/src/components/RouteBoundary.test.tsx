import { render, screen } from "@testing-library/react"
import i18n from "@/i18n"
import { page } from "@/lib/chunks"
import { RouteBoundary } from "./RouteBoundary"

function Broken({ error }: { error: Error }): never {
  throw error
}

const chunkError = () => new TypeError("Failed to fetch dynamically imported module: /assets/StatsScreen-abc.js")

describe("RouteBoundary", () => {
  beforeEach(() => {
    i18n.changeLanguage("en")
    sessionStorage.clear()
    vi.spyOn(console, "error").mockImplementation(() => {})
  })
  afterEach(() => vi.restoreAllMocks())

  it("reloads the page once when a lazy chunk fails to load", () => {
    const reload = vi.spyOn(page, "reload").mockImplementation(() => {})
    render(<RouteBoundary><Broken error={chunkError()} /></RouteBoundary>)
    expect(reload).toHaveBeenCalledTimes(1)
  })

  it("shows a retry message instead of reloading again right after a reload", () => {
    const reload = vi.spyOn(page, "reload").mockImplementation(() => {})
    render(<RouteBoundary><Broken error={chunkError()} /></RouteBoundary>)
    render(<RouteBoundary><Broken error={chunkError()} /></RouteBoundary>)

    expect(reload).toHaveBeenCalledTimes(1)
    expect(screen.getAllByText("Could not load this screen.").length).toBeGreaterThan(0)
  })

  it("does not reload for an ordinary render error", () => {
    const reload = vi.spyOn(page, "reload").mockImplementation(() => {})
    render(<RouteBoundary><Broken error={new Error("boom")} /></RouteBoundary>)

    expect(reload).not.toHaveBeenCalled()
    expect(screen.getByText("Could not load this screen.")).toBeInTheDocument()
    expect(screen.getByRole("button", { name: "Try again" })).toBeInTheDocument()
  })
})
