import { devices, expect, test, type Page } from "@playwright/test"
import { apiCall, seedLibrary, signUpAndIn } from "./helpers"

// Not a regression test: screenshots of every main screen for a human to look at. TOUR=1 to run.
test.skip(!process.env.TOUR, "set TOUR=1")

const dir = process.env.TOUR_DIR ?? "test-results/tour"
const widths = [390, 1440]

async function shoot(page: Page, name: string, fullPage = true) {
  await page.evaluate(() => document.fonts.ready)
  await page.waitForTimeout(400)
  await page.screenshot({ path: `${dir}/${name}-${page.viewportSize()!.width}.png`, fullPage })
}

for (const lng of ["en", "ru"]) {
  test(`tour ${lng}`, async ({ browser, baseURL }) => {
    test.setTimeout(240_000)
    for (const width of widths) {
      // setViewportSize drops touch emulation, so each width gets its own context.
      const context = await browser.newContext(
        width < 800
          ? { ...devices["iPhone 13"], viewport: { width, height: 844 }, baseURL }
          : { viewport: { width, height: 900 }, isMobile: false, hasTouch: false, deviceScaleFactor: 1, baseURL },
      )
      const page = await context.newPage()
      await page.addInitScript((l) => localStorage.setItem("i18nextLng", l), lng)
      await page.goto("/login")
      await shoot(page, `${lng}-login`)
      await page.goto("/register")
      await shoot(page, `${lng}-register`)

      await signUpAndIn(page)
      await page.goto("/")
      await expect(page.locator(".bs-onboard")).toBeVisible()
      await shoot(page, `${lng}-empty`)

      await seedLibrary(page.request)
      const shelf = await apiCall(page.request, "GET", "/shelf")
      const picnic = shelf.shelves.flatMap((s: { books: { id: string; title: string }[] }) => s.books).find((b: { title: string }) => b.title === "Пикник на обочине")
      await apiCall(page.request, "POST", `/books/${picnic.id}/notes`, { body: "Перечитать в оригинале. Финал у Шара совсем другой, чем в «Сталкере»." })
      await apiCall(page.request, "POST", `/books/${picnic.id}/editions`, { edition: { format: "ebook", store: "amazon", status: "done", finished_at: "2019-06-01" } })

      await page.goto("/")
      // Full-page screenshots reset Chromium's touch emulation, so the tap flow goes first.
      const spine = page.locator(".bs-spine", { hasText: "Пикник на обочине" })
      await spine.scrollIntoViewIfNeeded()
      await spine.click()
      if (width < 800) {
        await shoot(page, `${lng}-pulled`, false)
        await page.locator(".bs-shelf > .bs-caption").click()
      }
      await expect(page.locator(".bs-spread")).toBeVisible()
      await expect(page.locator(".bs-flap")).toHaveCount(0)
      await shoot(page, `${lng}-spread`, false)
      await page.keyboard.press("Escape")
      await shoot(page, `${lng}-bookcase`)

      await page.locator(".bs-search__input").fill(lng === "ru" ? "дюна" : "Ishiguro")
      await page.waitForTimeout(800)
      await shoot(page, `${lng}-search`)
      await page.locator(".bs-search__input").fill("Улитка на склоне дня")
      await page.waitForTimeout(800)
      await shoot(page, `${lng}-notfound`)
      await page.locator(".bs-search__input").fill("")

      await page.locator(".bs-shelfscreen__tools .bs-btn--secondary").click()
      await page.locator(".bs-entry input").first().fill("Sapiens")
      await page.locator(".bs-entry button[type=submit]").click()
      await expect(page.locator(".bs-field__error")).toBeVisible()
      await shoot(page, `${lng}-duplicate`, false)
      await page.keyboard.press("Escape")

      await page.locator(".bs-choice", { hasText: lng === "ru" ? "Список" : "List" }).click()
      await shoot(page, `${lng}-list`)
      await page.locator(".bs-choice", { hasText: lng === "ru" ? "Шкаф" : "Bookcase" }).click()

      await page.goto("/stats?")
      await page.goto("/stats")
      await expect(page.locator(".bs-year__sum")).toBeVisible()
      await shoot(page, `${lng}-stats`)
      await page.goto("/sources")
      await shoot(page, `${lng}-sources`)
      await page.goto("/sources/kindle")
      await shoot(page, `${lng}-remote-disclosure`)
      await page.goto("/profile")
      await shoot(page, `${lng}-profile`)
      await page.goto("/share?title=Солярис&text=https://www.litres.ru/x")
      await page.locator(".bs-answer[role=status]").waitFor()
      await shoot(page, `${lng}-share`)
      await context.close()
    }
  })
}
