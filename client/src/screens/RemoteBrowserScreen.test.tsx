import { act, render, screen } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { MemoryRouter } from "react-router-dom"
import i18n from "@/i18n"
import type { RemoteSession } from "@/lib/types"
import { RemoteBrowserScreen } from "./RemoteBrowserScreen"

const session = (overrides: Partial<RemoteSession> = {}): RemoteSession => ({
  id: "s1",
  purpose: "kindle",
  status: "collecting",
  steps: [{ key: "library", state: "pending" }],
  result: null,
  interruption: null,
  ...overrides,
})

type Reply = [number, unknown] | "offline"

function serve(handler: (url: string, init: RequestInit) => Reply) {
  vi.stubGlobal(
    "fetch",
    vi.fn(async (url: string, init: RequestInit = {}) => {
      const reply = handler(url, init)
      if (reply === "offline") throw new TypeError("Failed to fetch")
      return new Response(JSON.stringify(reply[1]), { status: reply[0] })
    }),
  )
}

const renderScreen = (purpose: RemoteSession["purpose"]) =>
  render(
    <MemoryRouter>
      <RemoteBrowserScreen purpose={purpose} />
    </MemoryRouter>,
  )

const becomeVisible = () => act(async () => void document.dispatchEvent(new Event("visibilitychange")))

describe("RemoteBrowserScreen", () => {
  beforeEach(() => i18n.changeLanguage("en"))
  afterEach(() => {
    vi.unstubAllGlobals()
    sessionStorage.clear()
  })

  it("keeps the session through a network error and resets it only on 404", async () => {
    sessionStorage.setItem("bs:remote:kindle", "s1")
    let reply: Reply = [200, { session: session() }]
    serve(() => reply)
    renderScreen("kindle")
    expect(await screen.findByText("Reading the library")).toBeInTheDocument()
    expect(screen.getByText("You can leave this screen. The result will appear on the Sources screen.")).toBeInTheDocument()

    reply = "offline"
    await becomeVisible()
    expect(screen.getByText("Reading the library")).toBeInTheDocument()
    expect(sessionStorage.getItem("bs:remote:kindle")).toBe("s1")

    reply = [404, { errors: [{ code: "not_found" }] }]
    await becomeVisible()
    expect(await screen.findByRole("button", { name: "Continue" })).toBeInTheDocument()
    expect(sessionStorage.getItem("bs:remote:kindle")).toBeNull()
  })

  it("shows a running session of the other purpose under its own purpose", async () => {
    serve(() => [200, { session: session({ status: "queued", queue_position: 2 }) }])
    renderScreen("litres")
    await userEvent.click(screen.getByRole("button", { name: "Continue" }))

    expect(await screen.findByRole("region", { name: "Sync Kindle" })).toBeInTheDocument()
    expect(sessionStorage.getItem("bs:remote:kindle")).toBe("s1")
    expect(sessionStorage.getItem("bs:remote:litres")).toBeNull()
  })

  it("draws the time bar against the server's sign-in window", async () => {
    sessionStorage.setItem("bs:remote:kindle", "s1")
    serve((url) =>
      url.endsWith("/viewer")
        ? [200, { url: "/view", expires_at: "2026-01-01T00:01:00Z" }]
        : [200, { session: session({ status: "live", login_window_seconds: 600, seconds_left: 300 }) }],
    )
    const { container } = renderScreen("kindle")
    await screen.findByRole("timer")
    expect(container.querySelector(".bs-session__bar")!.getAttribute("style")).toMatch(/--left: 50(\.\d+)?%/)
  })
})
