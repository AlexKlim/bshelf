import { expect, test } from "@playwright/test"
import { seedLibrary, signUpAndIn } from "./helpers"

test("a full shelf splits into rows, and a row that runs over does not push the walls", async ({ browser, baseURL }) => {
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 }, isMobile: false, hasTouch: false, baseURL })
  const page = await context.newPage()
  await signUpAndIn(page)
  const books = Array.from({ length: 40 }, (_, i) => ({ title: `Book ${i}`, author: "Author", format: "ebook", status: "done", finished: "2025-03-01" }))
  await seedLibrary(page.request, books as never)
  await page.goto("/")

  await expect(page.locator(".bs-shelf__row").nth(3)).toBeVisible()
  const column = await page.locator(".bs-shelfscreen").evaluate((el) => el.clientWidth)
  expect(await page.locator(".bs-case").evaluate((el) => el.getBoundingClientRect().width)).toBeLessThanOrEqual(column)

  const left = (selector: string) => page.locator(selector).first().evaluate((el) => Math.round(el.getBoundingClientRect().left))
  expect(await left(".bs-header .bs-wordmark")).toBe(await left(".bs-shelfscreen"))

  const shelfWidth = () => page.locator(".bs-shelf").first().evaluate((el) => el.getBoundingClientRect().width)
  const before = await shelfWidth()
  await page.locator(".bs-shelf__row").nth(2).evaluate((row) => {
    const extra = document.createElement("li")
    extra.style.cssText = "flex: none; inline-size: 100px"
    row.append(extra)
  })
  expect(await shelfWidth()).toBe(before)
})
