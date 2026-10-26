import { render, screen } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import i18n from "@/i18n"
import { mockFetch } from "@/test/fixtures"
import { LibrarianDesk } from "./LibrarianDesk"

describe("LibrarianDesk", () => {
  beforeEach(() => i18n.changeLanguage("en"))
  afterEach(() => vi.unstubAllGlobals())

  it("asks the server to tidy up and says how many books it took", async () => {
    const fetch = mockFetch(() => [200, { queued: 3, duplicates: false }])
    render(<LibrarianDesk onTidied={() => {}} />)

    await userEvent.click(screen.getByRole("button", { name: "Tidy up" }))

    expect(await screen.findByText("Working on 3 books. The bookcase will refresh by itself.")).toBeInTheDocument()
    expect(fetch.mock.calls[0][0]).toContain("/library/tidy")
  })
})
