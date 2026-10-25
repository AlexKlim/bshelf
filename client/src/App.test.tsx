import { render, screen } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { MemoryRouter } from "react-router-dom"
import i18n from "@/i18n"
import App from "./App"

describe("App shell", () => {
  beforeEach(() => i18n.changeLanguage("en"))

  it("renders the three tabs and marks the current one", () => {
    render(<MemoryRouter initialEntries={["/stats"]}><App /></MemoryRouter>)

    expect(screen.getAllByRole("tab")).toHaveLength(3)
    expect(screen.getByRole("tab", { name: "Stats" })).toHaveAttribute("aria-selected", "true")
  })

  it("navigates between tabs", async () => {
    render(<MemoryRouter><App /></MemoryRouter>)

    await userEvent.click(screen.getByRole("tab", { name: "Sources" }))

    expect(screen.getByRole("heading", { name: "Sources" })).toBeInTheDocument()
  })

  it("switches to Russian", async () => {
    await i18n.changeLanguage("ru")
    render(<MemoryRouter><App /></MemoryRouter>)

    expect(screen.getByRole("tab", { name: "Шкаф" })).toBeInTheDocument()
  })
})
