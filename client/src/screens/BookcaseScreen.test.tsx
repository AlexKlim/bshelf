import { render, screen } from "@testing-library/react"
import { MemoryRouter } from "react-router-dom"
import App from "@/App"
import i18n from "@/i18n"

const user = { id: "u1", email: "reader@example.com", created_at: "2026-10-25T10:00:00.000Z" }

describe("BookcaseScreen", () => {
  beforeEach(() => i18n.changeLanguage("en"))
  afterEach(() => {
    vi.unstubAllGlobals()
    localStorage.clear()
  })

  it("keeps one banner when the shelf cannot load offline: offline in the slot, a plain retry row below", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => {
        throw new TypeError("Failed to fetch")
      }),
    )
    const { container } = render(
      <MemoryRouter>
        <App initialUser={user} />
      </MemoryRouter>,
    )

    expect(await screen.findByText("Could not load the bookcase.")).toBeInTheDocument()
    expect(screen.getByText("No network. The bookcase is shown from cache.")).toBeInTheDocument()
    expect(container.querySelectorAll(".bs-banner")).toHaveLength(1)
    expect(screen.queryByRole("alert")).toBeNull()
    expect(screen.getByRole("button", { name: "Try again" })).toBeInTheDocument()
  })
})
