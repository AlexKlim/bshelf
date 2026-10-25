import { render, screen } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import i18n from "@/i18n"
import { book, edition, mockFetch } from "@/test/fixtures"
import { EntryForm } from "./EntryForm"

const existing = book({ shelf: "2024", editions: [edition({ format: "audio", status: "done", finished_at: "2024-03-10T00:00:00.000Z" })] })

describe("EntryForm", () => {
  afterEach(async () => {
    vi.unstubAllGlobals()
    await i18n.changeLanguage("en")
  })

  it("shows the duplicate error at the title field, not as a toast", async () => {
    await i18n.changeLanguage("en")
    mockFetch(() => [409, { errors: [{ code: "duplicate", field: "title" }], existing }])
    const onSaved = vi.fn()
    render(<EntryForm onSaved={onSaved} onCancel={() => {}} />)

    await userEvent.type(screen.getByLabelText("Title"), "Solaris")
    await userEvent.click(screen.getByRole("button", { name: "Write it in" }))

    const title = screen.getByLabelText("Title")
    expect(await screen.findByText("Already on the shelf: Listened · 2024")).toBeInTheDocument()
    expect(title).toHaveAttribute("aria-invalid", "true")
    expect(title).toHaveAccessibleDescription("Already on the shelf: Listened · 2024")
    expect(screen.queryByRole("alert")).toBeNull()
    expect(onSaved).not.toHaveBeenCalled()
  })

  it("says it in Russian with the status form of the format", async () => {
    await i18n.changeLanguage("ru")
    mockFetch(() => [409, { errors: [{ code: "duplicate", field: "title" }], existing }])
    render(<EntryForm onSaved={() => {}} onCancel={() => {}} />)

    await userEvent.type(screen.getByLabelText("Название"), "Солярис")
    await userEvent.click(screen.getByRole("button", { name: "Записать" }))

    expect(await screen.findByText("Уже на полке: Прослушал · 2024")).toBeInTheDocument()
  })

  it("sends the chosen format, status and month, and changes the status words with the format", async () => {
    await i18n.changeLanguage("en")
    const fetch = mockFetch(() => [201, { book: existing }])
    render(<EntryForm onSaved={() => {}} onCancel={() => {}} />)

    await userEvent.type(screen.getByLabelText("Title"), "Solaris")
    await userEvent.click(screen.getByRole("radio", { name: "Audio" }))
    await userEvent.click(screen.getByRole("radio", { name: "Listened" }))
    await userEvent.type(screen.getByLabelText("When"), "2024-03")
    await userEvent.click(screen.getByRole("button", { name: "Write it in" }))

    const body = JSON.parse(fetch.mock.calls[0][1].body as string)
    expect(body).toEqual({ title: "Solaris", edition: { format: "audio", status: "done", finished_at: "2024-03-01" } })
  })

  it("asks for a title before sending", async () => {
    const fetch = mockFetch(() => [201, {}])
    render(<EntryForm onSaved={() => {}} onCancel={() => {}} />)
    await userEvent.click(screen.getByRole("button", { name: "Write it in" }))
    expect(screen.getByLabelText("Title")).toHaveAccessibleDescription("Fill in this field.")
    expect(fetch).not.toHaveBeenCalled()
  })
})
