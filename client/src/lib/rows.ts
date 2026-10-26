export function splitRows(widths: number[], capacity: number, gap = 2): number[][] {
  const rows: number[][] = [[]]
  let used = 0
  widths.forEach((width, i) => {
    const row = rows[rows.length - 1]
    const needed = row.length ? used + gap + width : width
    if (row.length && needed > capacity) {
      rows.push([i])
      used = width
    } else {
      row.push(i)
      used = needed
    }
  })
  return rows
}
