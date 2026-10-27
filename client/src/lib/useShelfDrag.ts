import {
  useCallback,
  useRef,
  useState,
  type PointerEvent as ReactPointerEvent,
} from "react";

export type ShelfDrag<T, K extends string> = {
  item: T;
  id: string;
  from: K;
  x: number;
  y: number;
  over: K | null;
  index: number;
};

// A finger has to rest on a spine before it lifts, otherwise the touch scrolls the shelf as before.
const HOLD_MS = 400;
const SLOP = 6;

function dropAt<K extends string>(x: number, y: number, id: string) {
  const shelf = document
    .elementFromPoint(x, y)
    ?.closest<HTMLElement>("[data-shelf]");
  if (!shelf) return { over: null, index: 0 };
  const rows = [...shelf.querySelectorAll<HTMLElement>(".bs-shelf__row")];
  if (!rows.length) return { over: shelf.dataset.shelf as K, index: 0 };
  const row =
    rows.find((r) => r.getBoundingClientRect().bottom >= y) ??
    rows[rows.length - 1];
  const staying = (el: Element) =>
    [...el.querySelectorAll<HTMLElement>("[data-book]")].filter(
      (s) => s.dataset.book !== id,
    );
  const before = rows
    .slice(0, rows.indexOf(row))
    .reduce((n, r) => n + staying(r).length, 0);
  const index = staying(row).filter((s) => {
    const r = s.getBoundingClientRect();
    return r.left + r.width / 2 < x;
  }).length;
  return { over: shelf.dataset.shelf as K, index: before + index };
}

export function useShelfDrag<T, K extends string>(
  onDrop?: (item: T, to: K, index: number) => void,
) {
  const [drag, setDrag] = useState<ShelfDrag<T, K> | null>(null);
  const dropped = useRef(false);

  const onPointerDown = useCallback(
    (e: ReactPointerEvent, item: T, id: string, from: K, at: number) => {
      if (!onDrop || !e.isPrimary || e.button !== 0) return;
      dropped.current = false;
      const touch = e.pointerType !== "mouse";
      const origin = { x: e.clientX, y: e.clientY };
      let current: ShelfDrag<T, K> | null = null;

      const show = (x: number, y: number) => {
        current = { item, id, from, x, y, ...dropAt<K>(x, y, id) };
        setDrag(current);
      };
      const hold = touch
        ? window.setTimeout(() => show(origin.x, origin.y), HOLD_MS)
        : undefined;

      const move = (ev: PointerEvent) => {
        if (ev.pointerId !== e.pointerId) return;
        if (
          !current &&
          Math.hypot(ev.clientX - origin.x, ev.clientY - origin.y) <= SLOP
        )
          return;
        if (!current && touch) return stop();
        show(ev.clientX, ev.clientY);
      };
      const keepStill = (ev: Event) => {
        if (current) ev.preventDefault();
      };
      const up = (ev: PointerEvent) => {
        if (ev.pointerId !== e.pointerId) return;
        const done: ShelfDrag<T, K> | null = current;
        if (done) dropped.current = true;
        stop();
        if (done?.over && (done.over !== from || done.index !== at))
          onDrop(done.item, done.over, done.index);
      };
      const escape = (ev: KeyboardEvent) => {
        if (ev.key === "Escape") stop();
      };
      function stop() {
        window.clearTimeout(hold);
        window.removeEventListener("pointermove", move);
        window.removeEventListener("pointerup", up);
        window.removeEventListener("pointercancel", stop);
        window.removeEventListener("keydown", escape);
        window.removeEventListener("touchmove", keepStill);
        window.removeEventListener("contextmenu", keepStill);
        current = null;
        setDrag(null);
      }

      window.addEventListener("pointermove", move);
      window.addEventListener("pointerup", up);
      window.addEventListener("pointercancel", stop);
      window.addEventListener("keydown", escape);
      window.addEventListener("touchmove", keepStill, { passive: false });
      window.addEventListener("contextmenu", keepStill);
    },
    [onDrop],
  );

  const takeDrop = useCallback(() => {
    const was = dropped.current;
    dropped.current = false;
    return was;
  }, []);

  return { drag, onPointerDown, takeDrop };
}
