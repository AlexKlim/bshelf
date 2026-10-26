import { useCallback, useRef, useState, type PointerEvent as ReactPointerEvent } from "react"

export type ShelfDrag<T, K extends string> = { item: T; from: K; x: number; y: number; over: K | null }

// A finger has to rest on a spine before it lifts, otherwise the touch scrolls the shelf as before.
const HOLD_MS = 400
const SLOP = 6

const shelfAt = <K extends string>(x: number, y: number) =>
  (document.elementFromPoint(x, y)?.closest<HTMLElement>("[data-shelf]")?.dataset.shelf ?? null) as K | null

export function useShelfDrag<T, K extends string>(onDrop?: (item: T, to: K) => void) {
  const [drag, setDrag] = useState<ShelfDrag<T, K> | null>(null)
  const dropped = useRef(false)

  const onPointerDown = useCallback(
    (e: ReactPointerEvent, item: T, from: K) => {
      if (!onDrop || !e.isPrimary || e.button !== 0) return
      dropped.current = false
      const touch = e.pointerType !== "mouse"
      const origin = { x: e.clientX, y: e.clientY }
      let current: ShelfDrag<T, K> | null = null

      const show = (x: number, y: number) => {
        current = { item, from, x, y, over: shelfAt<K>(x, y) }
        setDrag(current)
      }
      const hold = touch ? window.setTimeout(() => show(origin.x, origin.y), HOLD_MS) : undefined

      const move = (ev: PointerEvent) => {
        if (ev.pointerId !== e.pointerId) return
        if (!current && Math.hypot(ev.clientX - origin.x, ev.clientY - origin.y) <= SLOP) return
        if (!current && touch) return stop()
        show(ev.clientX, ev.clientY)
      }
      const keepStill = (ev: Event) => {
        if (current) ev.preventDefault()
      }
      const up = (ev: PointerEvent) => {
        if (ev.pointerId !== e.pointerId) return
        const done: ShelfDrag<T, K> | null = current
        if (done) dropped.current = true
        stop()
        if (done?.over && done.over !== from) onDrop(done.item, done.over)
      }
      const escape = (ev: KeyboardEvent) => {
        if (ev.key === "Escape") stop()
      }
      function stop() {
        window.clearTimeout(hold)
        window.removeEventListener("pointermove", move)
        window.removeEventListener("pointerup", up)
        window.removeEventListener("pointercancel", stop)
        window.removeEventListener("keydown", escape)
        window.removeEventListener("touchmove", keepStill)
        window.removeEventListener("contextmenu", keepStill)
        current = null
        setDrag(null)
      }

      window.addEventListener("pointermove", move)
      window.addEventListener("pointerup", up)
      window.addEventListener("pointercancel", stop)
      window.addEventListener("keydown", escape)
      window.addEventListener("touchmove", keepStill, { passive: false })
      window.addEventListener("contextmenu", keepStill)
    },
    [onDrop],
  )

  const takeDrop = useCallback(() => {
    const was = dropped.current
    dropped.current = false
    return was
  }, [])

  return { drag, onPointerDown, takeDrop }
}
