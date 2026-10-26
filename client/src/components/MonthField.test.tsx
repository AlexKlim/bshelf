import { render, screen } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import i18n from "@/i18n"
import { MonthField } from "./ui"

describe("MonthField", () => {
  afterEach(() => i18n.changeLanguage("en"))

  it("names the months in the interface language, not the browser's", async () => {
    await i18n.changeLanguage("ru")
    render(<MonthField label="Когда" value="2024-10" onChange={() => {}} />)

    expect(screen.getByLabelText("Когда")).toHaveTextContent("октябрь 2024")
    await userEvent.click(screen.getByLabelText("Когда"))
    expect(screen.getByRole("button", { name: "окт." })).toHaveAttribute("aria-pressed", "true")
    expect(screen.getByRole("button", { name: "Очистить" })).toBeInTheDocument()
  })
})
