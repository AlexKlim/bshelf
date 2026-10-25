export const findOpener = (bookId: string) =>
  [...document.querySelectorAll<HTMLElement>("[data-book]")].find((el) => el.dataset.book === bookId)
