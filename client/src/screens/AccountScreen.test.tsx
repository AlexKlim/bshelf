import { render, screen, within } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { MemoryRouter } from "react-router-dom"
import App from "@/App"
import i18n from "@/i18n"
import type { Assistant } from "@/lib/types"
import { mockFetch } from "@/test/fixtures"

const user = { id: "u1", email: "reader@example.com", created_at: "2026-10-25T10:00:00.000Z" }
const claude: Assistant = {
  id: "a1",
  name: "claude.ai",
  client_id: "https://claude.ai/oauth/mcp-client-metadata",
  scopes: ["books:read"],
  connected_at: "2026-10-25T10:00:00.000Z",
  last_active_at: null,
}

function serve(extra: (url: string, init: RequestInit) => [number, unknown] | undefined = () => undefined) {
  return mockFetch((url, init) => {
    const answer = extra(url, init)
    if (answer) return answer
    if (init.method === "DELETE") return [204, null]
    if (url === "/api/v1/assistants") return [200, { assistants: [claude], gemini_client: null }]
    if (url === "/api/v1/api_tokens") return [200, { api_tokens: [] }]
    if (url.startsWith("/api/v1/shelf")) return [200, { shelves: [] }]
    return [404, { errors: [{ code: "not_found" }] }]
  })
}

const open = (path: string) =>
  render(
    <MemoryRouter initialEntries={[path]}>
      <App initialUser={user} />
    </MemoryRouter>,
  )

function desktopWidth() {
  vi.stubGlobal("matchMedia", (query: string) => ({
    matches: query === "(min-width: 768px)",
    media: query,
    addEventListener: () => {},
    removeEventListener: () => {},
  }))
}

describe("Account", () => {
  beforeEach(() => i18n.changeLanguage("en"))
  afterEach(() => vi.unstubAllGlobals())

  it("lists the sections on a phone with the connected assistant count", async () => {
    serve()
    open("/account")

    expect(await screen.findByRole("heading", { level: 1, name: "Account" })).toBeInTheDocument()
    expect(screen.getByText("reader@example.com")).toBeInTheDocument()
    const nav = screen.getByRole("navigation", { name: "Account sections" })
    expect(within(nav).getAllByRole("link").map((a) => a.getAttribute("href"))).toEqual([
      "/account/profile",
      "/account/shortcut",
      "/account/assistants",
      "/account/language",
      "/account/delete",
    ])
    expect(await within(nav).findByText("Claude, ChatGPT, Gemini · 1 connected")).toBeInTheDocument()
    expect(within(nav).getByRole("link", { name: "Delete account" })).toHaveClass("ac-danger")
    expect(screen.getByRole("link", { name: "Account" })).toHaveAttribute("aria-current", "page")
  })

  it("opens a section with a way back on a phone", async () => {
    serve()
    open("/profile")

    await userEvent.click(await screen.findByRole("link", { name: /Language/ }))

    expect(await screen.findByRole("heading", { level: 1, name: "Language" })).toBeInTheDocument()
    expect(screen.getByRole("link", { name: "‹ Account" })).toHaveAttribute("href", "/account")
  })

  it("goes straight to the profile on a desktop with the sub-menu beside it", async () => {
    desktopWidth()
    serve()
    open("/account")

    expect(await screen.findByRole("heading", { level: 2, name: "Profile and password" })).toBeInTheDocument()
    const nav = screen.getByRole("navigation", { name: "Account sections" })
    expect(within(nav).getByRole("link", { name: "Profile and password" })).toHaveAttribute("aria-current", "page")
    expect(within(nav).getByRole("link", { name: "Assistants (MCP)" })).not.toHaveAttribute("aria-current")
  })

  describe("assistants", () => {
    it("shows the MCP URL, copies it, lists assistants and revokes one", async () => {
      const fetch = serve()
      open("/account/assistants")
      const actor = userEvent.setup()
      const writeText = vi.spyOn(navigator.clipboard, "writeText")

      const url = `${window.location.origin}/mcp`
      expect(await screen.findByText(url)).toBeInTheDocument()
      await actor.click(screen.getByText(url).parentElement!.querySelector("button")!)
      expect(writeText).toHaveBeenCalledWith(url)
      expect(await screen.findByText("Copied")).toBeInTheDocument()

      expect(screen.getByRole("heading", { name: "How to connect Claude" })).toBeInTheDocument()
      expect(screen.getByText("Open the connector settings")).toBeInTheDocument()

      expect(await screen.findByText("claude.ai")).toBeInTheDocument()
      await actor.click(screen.getByRole("button", { name: "Revoke" }))
      expect(fetch).toHaveBeenCalledWith("/api/v1/assistants/a1", expect.objectContaining({ method: "DELETE" }))
      expect(await screen.findByText("No assistants connected.")).toBeInTheDocument()
    })

    it("switches the steps to ChatGPT and Gemini and shows the Gemini secret once", async () => {
      const fetch = serve((url, init) =>
        url === "/api/v1/assistants/gemini_client" && init.method === "POST"
          ? [201, { client_id: "gem-id", client_secret: "gem-secret" }]
          : undefined,
      )
      open("/account/assistants")

      await userEvent.click(await screen.findByRole("radio", { name: "ChatGPT" }))
      expect(screen.getByRole("heading", { name: "How to connect ChatGPT" })).toBeInTheDocument()
      expect(screen.getByText("Turn on developer mode")).toBeInTheDocument()

      await userEvent.click(screen.getByRole("radio", { name: "Gemini" }))
      expect(screen.getByText("For Gemini Enterprise and Gemini Business.")).toBeInTheDocument()
      expect(screen.getByText(`${window.location.origin}/oauth/authorize`)).toBeInTheDocument()
      expect(screen.getByText(`${window.location.origin}/oauth/token`)).toBeInTheDocument()

      await userEvent.click(screen.getByRole("button", { name: "Create a key for Gemini" }))

      expect(await screen.findByText("gem-secret")).toBeInTheDocument()
      expect(screen.getByText("gem-id")).toBeInTheDocument()
      expect(screen.getByText("Copy it now: the secret is shown only once.")).toBeInTheDocument()
      expect(fetch).toHaveBeenCalledWith("/api/v1/assistants/gemini_client", expect.objectContaining({ method: "POST" }))
    })
  })

  describe("change password", () => {
    it("shows field errors and confirms the change", async () => {
      let answer: [number, unknown] = [422, { errors: [{ code: "invalid", field: "current_password" }] }]
      const fetch = serve((url) => (url === "/api/v1/me/password" ? answer : undefined))
      open("/account/profile")
      const save = await screen.findByRole("button", { name: "Save password" })

      await userEvent.click(save)
      expect(screen.getByLabelText("Current password")).toHaveAccessibleDescription("Fill in this field.")
      expect(screen.getByLabelText("New password")).toHaveAccessibleDescription("Fill in this field.")

      await userEvent.type(screen.getByLabelText("Current password"), "nope")
      await userEvent.type(screen.getByLabelText("New password"), "new-password")
      await userEvent.click(save)
      expect(await screen.findByText("Wrong password.")).toBeInTheDocument()
      expect(fetch).toHaveBeenCalledWith(
        "/api/v1/me/password",
        expect.objectContaining({ method: "PATCH", body: JSON.stringify({ current_password: "nope", password: "new-password" }) }),
      )

      answer = [422, { errors: [{ code: "too_short", field: "password" }] }]
      await userEvent.click(save)
      expect(await screen.findByText("Too short.")).toBeInTheDocument()

      answer = [204, null]
      await userEvent.click(save)
      expect(await screen.findByText("Password changed")).toBeInTheDocument()
      expect(screen.getByLabelText("Current password")).toHaveValue("")
    })
  })
})
