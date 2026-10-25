import i18n from "@/i18n"
import { book, edition } from "@/test/fixtures"
import { answerLine, monthYear, primaryEdition, sinceMonth, statusLine, statusWord } from "./vocab"

const t = i18n.t.bind(i18n)

describe("status vocabulary", () => {
  afterEach(() => i18n.changeLanguage("en"))

  it.each([
    ["en", "want", "audio", "Want"],
    ["en", "owned", "ebook", "Owned"],
    ["en", "in_progress", "audio", "Listening"],
    ["en", "in_progress", "ebook", "Reading"],
    ["en", "done", "audio", "Listened"],
    ["en", "done", "unknown", "Read"],
    ["ru", "want", "audio", "Хочу"],
    ["ru", "owned", "ebook", "На полке"],
    ["ru", "in_progress", "audio", "Слушаю"],
    ["ru", "in_progress", "ebook", "Читаю"],
    ["ru", "done", "audio", "Прослушал"],
    ["ru", "done", "ebook", "Прочитал"],
  ] as const)("%s %s %s -> %s", async (lng, status, format, word) => {
    await i18n.changeLanguage(lng)
    expect(statusWord(t, status, format)).toBe(word)
  })

  it("joins status and month with a middle dot and drops the Russian year suffix", async () => {
    const done = edition({ format: "audio", status: "done", finished_at: "2024-03-10T00:00:00.000Z" })
    expect(statusLine(t, "en", done)).toBe("Listened · Mar 2024")
    await i18n.changeLanguage("ru")
    expect(statusLine(t, "ru", done)).toBe("Прослушал · март 2024")
    expect(monthYear("2024-03-10T00:00:00.000Z", "ru")).toBe("март 2024")
  })

  it("uses the genitive month after «с»", async () => {
    await i18n.changeLanguage("ru")
    const want = edition({ status: "want", status_updated_at: "2025-05-04T00:00:00.000Z" })
    expect(sinceMonth("2025-05-04T00:00:00.000Z", "ru")).toBe("мая 2025")
    expect(statusLine(t, "ru", want)).toBe("Хочу · с мая 2025")
    expect(statusLine(t, "ru", want, { separator: ", " })).toBe("Хочу, с мая 2025")
  })

  it("shortens to the month on a year shelf and shows the bare status without a date", () => {
    expect(statusLine(t, "en", edition({ format: "ebook" }), { monthOnly: true })).toBe("Read · Mar")
    expect(statusLine(t, "en", edition({ finished_at: null }))).toBe("Listened")
  })

  it("picks the edition in progress over a finished one", () => {
    const reading = edition({ status: "in_progress", format: "ebook" })
    expect(primaryEdition(book({ editions: [edition(), reading] }))).toBe(reading)
  })

  it("answers the search in one line (D11)", async () => {
    const both = book({
      id: "x",
      editions: [
        edition({ format: "ebook", finished_at: "2023-02-01T00:00:00.000Z" }),
        edition({ format: "audio", finished_at: "2024-03-10T00:00:00.000Z" }),
      ],
    })
    const result = (kind: string, extra = {}) => ({ query: "q", answer: { kind, book_id: "x", ...extra }, books: [both] }) as never
    expect(answerLine(t, "en", result("listened"))).toBe("Listened · Mar 2024")
    expect(answerLine(t, "en", result("read_and_listened"))).toBe("Read and listened · 2023, 2024")
    expect(answerLine(t, "en", result("similar", { count: 2 }))).toBe("Similar: 2 books")
    expect(answerLine(t, "en", result("not_found"))).toBe("Not on the shelf")
    await i18n.changeLanguage("ru")
    expect(answerLine(t, "ru", result("listened"))).toBe("Слушали · март 2024")
    expect(answerLine(t, "ru", result("similar", { count: 5 }))).toBe("Похожие: 5 книг")
  })
})
