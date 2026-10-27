import { expect, test } from "@playwright/test"
import { seedLibrary, signUpAndIn } from "./helpers"

test("a full shelf splits into rows instead of widening the bookcase", async ({ browser, baseURL }) => {
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 }, isMobile: false, hasTouch: false, baseURL })
  const page = await context.newPage()
  await signUpAndIn(page)
  const books = Array.from({ length: 40 }, (_, i) => ({ title: `Book ${i}`, author: "Author", format: "ebook", status: "done", finished: "2025-03-01" }))
  await seedLibrary(page.request, books as never)
  await page.goto("/")

  await expect(page.locator(".bs-shelf__row").nth(3)).toBeVisible()
  const column = await page.locator(".bs-shelfscreen").evaluate((el) => el.clientWidth)
  expect(await page.locator(".bs-case").evaluate((el) => el.getBoundingClientRect().width)).toBeLessThanOrEqual(column)
})
