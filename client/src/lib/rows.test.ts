import { splitRows } from "./rows"

describe("splitRows", () => {
  it("fills a row up to the shelf width and carries the rest to the next", () => {
    expect(splitRows([30, 30, 30, 30], 95)).toEqual([[0, 1, 2], [3]])
    expect(splitRows([30, 30], Infinity)).toEqual([[0, 1]])
    expect(splitRows([200, 30], 100)).toEqual([[0], [1]])
    expect(splitRows([], 100)).toEqual([[]])
  })
})
