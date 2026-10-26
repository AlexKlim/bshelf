import { render, screen, waitFor } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { MemoryRouter } from "react-router-dom"
import i18n from "@/i18n"
import type { Duplicate } from "@/lib/types"
import { book, mockFetch } from "@/test/fixtures"
import { KindleExportScreen, SourcesScreen } from "./SourcesScreen"

const duplicate: Duplicate = {
  id: "d1",
  reason: "title",
  created_at: "2026-01-01T00:00:00Z",
  books: [book({ id: "x1", title: "Solaris" }), book({ id: "x2", title: "Solaris (EN)" })],
}

const renderSources = () =>
  render(
    <MemoryRouter>
      <SourcesScreen />
    </MemoryRouter>,
  )

describe("sources that the server does not offer yet", () => {
  beforeEach(() => i18n.changeLanguage("en"))
  afterEach(() => vi.unstubAllGlobals())

  it("says the Amazon export request is not available yet on 404", async () => {
    mockFetch(() => [404, { errors: [{ code: "not_found" }] }])
    render(
      <MemoryRouter>
        <KindleExportScreen />
      </MemoryRouter>,
    )
    await userEvent.click(screen.getByRole("button", { name: "I have requested it" }))
    expect(await screen.findByText("Not available yet: this is coming later.")).toBeInTheDocument()
    expect(screen.queryByText("Not found.")).toBeNull()
  })

  it("says the archive upload is not available yet", async () => {
    mockFetch((url) => {
      if (url === "/api/v1/sources") {
        return [200, { sources: [{ kind: "kindle_export", status: "ready", last_sync_at: null, error: null, books_count: 0, session: null }], banner: null }]
      }
      if (url === "/api/v1/duplicates") return [200, { duplicates: [] }]
      return [501, { errors: [{ code: "not_implemented" }] }]
    })
    const { container } = renderSources()
    await screen.findByText("Upload archive")
    await userEvent.upload(container.querySelector<HTMLInputElement>("input[type=file]")!, new File(["x"], "export.zip"))
    expect(await screen.findByText("Not available yet: this is coming later.")).toBeInTheDocument()
  })
})

describe("Possible duplicates", () => {
  beforeEach(() => i18n.changeLanguage("en"))
  afterEach(() => vi.unstubAllGlobals())

  function serve(dismiss: [number, unknown], undo: [number, unknown] = [200, { books: [] }]) {
    return mockFetch((url, init) => {
      if (url === "/api/v1/sources") return [200, { sources: [], banner: null }]
      if (url === "/api/v1/duplicates") return [200, { duplicates: [duplicate] }]
      if (url === "/api/v1/duplicates/d1" && init.method === "DELETE") return dismiss
      if (url === "/api/v1/books/x1/merge") return [200, { book: { ...duplicate.books[0] }, merge_id: "m1" }]
      if (url === "/api/v1/merges/m1") return undo
      return [404, {}]
    })
  }

  it("keeps the row and says why when dismissing fails", async () => {
    serve([500, { errors: [{ code: "generic" }] }])
    renderSources()
    await userEvent.click(await screen.findByRole("button", { name: "Not a duplicate" }))
    expect(await screen.findByText("Something went wrong. Try again.")).toBeInTheDocument()
    expect(screen.getByText("Solaris (EN)")).toBeInTheDocument()
  })

  it("drops the row when the pair is already gone", async () => {
    serve([404, { errors: [{ code: "not_found" }] }])
    renderSources()
    await userEvent.click(await screen.findByRole("button", { name: "Not a duplicate" }))
    await waitFor(() => expect(screen.queryByText("Solaris (EN)")).toBeNull())
    expect(screen.queryByText("Not found.")).toBeNull()
  })

  it("shows the error when Undo fails and drops the notice on 404", async () => {
    serve([204, null], [409, { errors: [{ code: "already_unmerged" }] }])
    const { unmount } = renderSources()
    await userEvent.click(await screen.findByRole("button", { name: "Merge" }))
    await userEvent.click(await screen.findByRole("button", { name: "Unmerge editions" }))
    expect(await screen.findByText("These editions are already separate.")).toBeInTheDocument()
    unmount()

    vi.unstubAllGlobals()
    serve([204, null], [404, { errors: [{ code: "not_found" }] }])
    renderSources()
    await userEvent.click(await screen.findByRole("button", { name: "Merge" }))
    await userEvent.click(await screen.findByRole("button", { name: "Unmerge editions" }))
    await waitFor(() => expect(screen.queryByText("Merged: Solaris")).toBeNull())
  })
})
