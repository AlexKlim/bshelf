import { render, screen } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { MemoryRouter } from "react-router-dom"
import { SearchField } from "@/components/SearchField"
import i18n from "@/i18n"
import { ShareScreen } from "./ShareScreen"

function serve(slow: string) {
  let release: () => void = () => {}
  const fetch = vi.fn((url: string) => {
    const reply = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status })
    if (url.startsWith(slow)) return new Promise<Response>((resolve) => (release = () => resolve(reply({ book: {}, message: "Written in." }, 201))))
    if (url.startsWith("/api/v1/share")) {
      return Promise.resolve(reply({ query: "Solaris", answer: { kind: "not_found" }, books: [], message: "", link: null, suggestion: { title: "Solaris", author: null, store: null, external_id: null } }))
    }
    if (url.startsWith("/api/v1/search")) return Promise.resolve(reply({ query: "Solaris", answer: { kind: "not_found" }, books: [] }))
    return Promise.resolve(reply({}, 404))
  })
  vi.stubGlobal("fetch", fetch)
  return { fetch, release: () => release() }
}

const calls = (fetch: ReturnType<typeof vi.fn>, path: string) => fetch.mock.calls.filter(([url]) => String(url).startsWith(path)).length

describe("quick add buttons", () => {
  beforeEach(() => i18n.changeLanguage("en"))
  afterEach(() => vi.unstubAllGlobals())

  it("on the share page are disabled while the add is in flight", async () => {
    const { fetch, release } = serve("/api/v1/share/add")
    render(
      <MemoryRouter initialEntries={["/share?title=Solaris"]}>
        <ShareScreen />
      </MemoryRouter>,
    )
    const read = await screen.findByRole("button", { name: "Read it" })
    await userEvent.click(read)
    await userEvent.click(read)

    expect(read).toBeDisabled()
    expect(screen.getByRole("button", { name: "Listened to it" })).toBeDisabled()
    expect(calls(fetch, "/api/v1/share/add")).toBe(1)
    release()
    expect(await screen.findByText("Written in.")).toBeInTheDocument()
  })

  it("under the search are disabled while Want is being added", async () => {
    const { fetch } = serve("/api/v1/books")
    render(<SearchField onMatches={() => {}} onWrite={() => {}} onAdded={() => {}} />)
    await userEvent.type(screen.getByRole("searchbox"), "Solaris")
    const want = await screen.findByRole("button", { name: "Want" })
    await userEvent.click(want)
    await userEvent.click(want)

    expect(want).toBeDisabled()
    expect(screen.getByRole("button", { name: "Read it" })).toBeDisabled()
    expect(calls(fetch, "/api/v1/books")).toBe(1)
  })
})
