import {
  useEffect,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
  type CSSProperties,
} from "react";
import { useTranslation } from "react-i18next";
import hallImage from "@/assets/library-hall.jpg";
import { shelfLabel } from "@/lib/arrange";
import { clothStyle, hash, spineSize } from "@/lib/cloth";
import type { BookSummary, Cloth, Shelf, ShelfKey } from "@/lib/types";
import { useMediaQuery } from "@/lib/useMediaQuery";
import { useTidy } from "@/lib/useTidy";
import { Bookcase } from "./Bookcase";

type Props = {
  shelves: Shelf[];
  matches?: ReadonlySet<string>;
  onOpen: (book: BookSummary) => void;
  onMore?: (key: ShelfKey) => void;
  onMove?: (book: BookSummary, to: ShelfKey, index: number) => void;
  disabled?: boolean;
  onTidied: () => void;
  onAdd: () => void;
  onList: () => void;
  onFind: () => void;
};

type Mini = {
  id: string;
  w: number;
  h: number;
  cloth: Cloth;
  color?: string | null;
};
type MiniShelf = { label: string; spines: Mini[] };
type HallCase = {
  key: string;
  plaque: string;
  label: string;
  shelves: Shelf[];
  minis: MiniShelf[];
};

const SCENE_W = 1200;
const SLOTS = [
  { x: 290, z: -150, phi: 28 },
  { x: 910, z: -150, phi: -28 },
  { x: 340, z: -1000, phi: 40 },
  { x: 860, z: -1000, phi: -40 },
  { x: 340, z: -1560, phi: 40 },
  { x: 860, z: -1560, phi: -40 },
  { x: 340, z: -2120, phi: 40 },
];
const ROW_TOPS = [58, 146, 234, 322, 410];
const BOARD_TOPS = [50, 138, 226, 314, 402, 490];
const ROW_WIDTH = 264;
const APPROACH_MS = 650;
const LEAVE_MS = 300;
const CLOTHS: Cloth[] = [
  "oxblood",
  "bottle",
  "navy",
  "plum",
  "slate",
  "ochre",
  "sage",
  "linen",
];
const TOOL_TIPS = {
  desk: { x: 1010, y: 568 },
  catalog: { x: 420, y: 262 },
  add: { x: 596, y: 268 },
  tidy: { x: 758, y: 274 },
  find: { x: 832, y: 358 },
};
type Tip = keyof typeof TOOL_TIPS;

const mini = (book: BookSummary): Mini => {
  const { width, height } = spineSize(book);
  return {
    id: book.id,
    w: Math.round(width * 0.36),
    h: Math.min(76, Math.round(height * 0.42)),
    cloth: book.cloth,
    color: book.cloth_color,
  };
};

function stack(groups: { label: string; books: BookSummary[] }[]) {
  const rows: MiniShelf[] = [];
  for (const group of groups) {
    let row: MiniShelf = { label: group.label, spines: [] };
    let used = 0;
    rows.push(row);
    for (const book of group.books) {
      const m = mini(book);
      if (used + m.w > ROW_WIDTH) {
        if (rows.length === ROW_TOPS.length) return rows;
        row = { label: "", spines: [] };
        rows.push(row);
        used = 0;
      }
      row.spines.push(m);
      used += m.w + 1;
    }
    if (rows.length === ROW_TOPS.length) return rows;
  }
  return rows;
}

function decorMinis(seed: number): MiniShelf[] {
  const h = (n: number) => hash(`${seed}:${n}`);
  return ROW_TOPS.map((_, r) => {
    const spines: Mini[] = [];
    let used = 0;
    for (let i = 0; used < ROW_WIDTH * (0.4 + (h(r) % 50) / 100); i++) {
      const v = h(r * 100 + i);
      const w = 10 + (v % 6);
      spines.push({
        id: `${seed}-${r}-${i}`,
        w,
        h: 58 + ((v >>> 4) % 4) * 5,
        cloth: CLOTHS[(v >>> 8) % CLOTHS.length],
      });
      used += w + 1;
    }
    return { label: "", spines };
  });
}

function useSceneScale() {
  const ref = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState(1);
  useLayoutEffect(() => {
    const el = ref.current;
    if (!el || typeof ResizeObserver === "undefined") return;
    const observer = new ResizeObserver(([entry]) =>
      setScale(entry.contentRect.width / SCENE_W),
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, []);
  return { ref, scale };
}

function Chevron({ back }: { back?: boolean }) {
  return (
    <svg
      aria-hidden="true"
      width="18"
      height="18"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d={back ? "M15 18l-6-6 6-6" : "M9 18l6-6-6-6"} />
    </svg>
  );
}

export function LibraryHall({
  shelves,
  matches,
  onOpen,
  onMore,
  onMove,
  disabled,
  onTidied,
  onAdd,
  onList,
  onFind,
}: Props) {
  const { t } = useTranslation();
  const reduced = useMediaQuery("(prefers-reduced-motion: reduce)");
  const { ref, scale } = useSceneScale();
  const { busy, note, tidy } = useTidy(onTidied);
  const [page, setPage] = useState(0);
  const [picked, setPicked] = useState<string | null>(null);
  const [nearing, setNearing] = useState<number | null>(null);
  const [openedKey, setOpenedKey] = useState<string | null>(null);
  const [closing, setClosing] = useState(false);
  const [atDesk, setAtDesk] = useState(false);
  const [tip, setTip] = useState<Tip | null>(null);
  const timer = useRef(0);
  const downOnStage = useRef(false);
  useEffect(() => () => window.clearTimeout(timer.current), []);

  const cases = useMemo<HallCase[]>(() => {
    const [now, want, ...rest] = shelves;
    const count = (s: Shelf) => `${shelfLabel(t, s.key)} · ${s.count}`;
    return [
      {
        key: "now",
        plaque: "",
        label: `${shelfLabel(t, now.key)}, ${shelfLabel(t, want.key)}`,
        shelves: [now, want],
        minis: stack([
          { label: count(now), books: now.books },
          { label: count(want), books: want.books },
        ]),
      },
      ...rest.map((s) => ({
        key: s.key,
        plaque: shelfLabel(t, s.key),
        label: t("hall.case", { label: shelfLabel(t, s.key), count: s.count }),
        shelves: [s],
        minis: stack([{ label: "", books: s.books }]),
      })),
    ];
  }, [shelves, t]);

  const pages = Math.ceil(cases.length / SLOTS.length);
  const current = Math.min(page, pages - 1);
  const slots = SLOTS.map((slot, i) => ({
    slot,
    index: current * SLOTS.length + i,
  }));
  const matched = (c: HallCase) =>
    !!matches?.size &&
    c.shelves.some((s) => s.books.some((b) => matches.has(b.id)));
  const onPage = cases
    .slice(current * SLOTS.length, (current + 1) * SLOTS.length)
    .filter((c) => c.plaque);
  const range = onPage.length
    ? [onPage[0].plaque, onPage.at(-1)!.plaque]
        .filter((v, i, a) => a.indexOf(v) === i)
        .join("-")
    : "";

  const opened =
    openedKey === null ? -1 : cases.findIndex((c) => c.key === openedKey);

  const approach = (index: number) => {
    if (nearing !== null || atDesk) return;
    const key = cases[index].key;
    setTip(null);
    if (reduced) return setOpenedKey(key);
    setNearing(index);
    timer.current = window.setTimeout(() => {
      setOpenedKey(key);
      setNearing(null);
    }, APPROACH_MS);
  };

  const leave = () => {
    if (closing) return;
    if (reduced) return setOpenedKey(null);
    setClosing(true);
    timer.current = window.setTimeout(() => {
      setOpenedKey(null);
      setClosing(false);
    }, LEAVE_MS);
  };

  const hall = useRef<HTMLDivElement>(null);
  const leaveRef = useRef(leave);
  useLayoutEffect(() => {
    leaveRef.current = leave;
  });
  const isOpen = opened >= 0;
  useEffect(() => {
    if (!isOpen) return;
    const onKey = (e: KeyboardEvent) => {
      const target = e.target as Node;
      if (e.key !== "Escape" || e.defaultPrevented) return;
      if (target !== document.body && !hall.current?.contains(target)) return;
      leaveRef.current();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [isOpen]);

  const go = (index: number) => {
    window.clearTimeout(timer.current);
    setClosing(false);
    setOpenedKey(cases[index].key);
    setPage(Math.floor(index / SLOTS.length));
  };

  const turn = (next: number) => {
    setPage(next);
    setPicked(null);
  };

  const tool = (name: Tip, action: () => void) => ({
    tabIndex: atDesk ? 0 : -1,
    onClick: () => (atDesk ? action() : setAtDesk(true)),
    onMouseEnter: () => atDesk && setTip(name),
    onMouseLeave: () => setTip(null),
    onFocus: () => setTip(name),
    onBlur: () => setTip(null),
  });

  const open = opened >= 0 ? cases[opened] : undefined;
  const earlier = open && cases[opened + 1];
  const later = open && opened > 0 ? cases[opened - 1] : undefined;
  const state = [
    nearing !== null && "is-nearing",
    open && !closing && "is-open",
    closing && "is-closing",
    atDesk && "is-desk",
  ]
    .filter(Boolean)
    .join(" ");

  return (
    <div ref={hall} className={`bs-hall ${state}`}>
      {open && (
        <div className="bs-hall__bar">
          <button
            type="button"
            className="bs-btn bs-btn--quiet"
            onClick={leave}
          >
            <Chevron back />
            {t("hall.back")}
          </button>
          <span className="bs-hall__steps">
            {earlier && (
              <button
                type="button"
                className="bs-btn bs-btn--quiet"
                onClick={() => go(opened + 1)}
              >
                <Chevron back />
                {earlier.plaque || earlier.label}
              </button>
            )}
            {later && (
              <button
                type="button"
                className="bs-btn bs-btn--quiet"
                onClick={() => go(opened - 1)}
              >
                {later.plaque || later.label}
                <Chevron />
              </button>
            )}
          </span>
        </div>
      )}
      <div ref={ref} className="bs-hall__frame">
        <div
          className="bs-hall__room"
          aria-hidden={open ? true : undefined}
          inert={!!open}
        >
          <div
            className="bs-hall__scene"
            style={{ "--k": scale } as CSSProperties}
          >
            <img className="bs-hall__backdrop" src={hallImage} alt="" />
            <div className="bs-hall__dim" />
            <div className="bs-hall__world" key={current}>
              {current === 0 && (
                <div className="bs-hall__window" aria-hidden="true" />
              )}
              {slots.map(({ slot, index }) => {
                const c = cases[index];
                const near = nearing === index || opened === index;
                const far = slot.z < -500;
                const minis = c ? c.minis : decorMinis(index);
                const className = [
                  "bs-hall__box",
                  near && "is-near",
                  far && "is-far",
                  c && (picked === c.key || matched(c)) && "is-picked",
                ]
                  .filter(Boolean)
                  .join(" ");
                return (
                  <div
                    key={index}
                    className={className}
                    style={
                      {
                        "--x": slot.x,
                        "--z": slot.z,
                        "--phi": slot.phi,
                        "--haze": Math.min(
                          0.5,
                          Math.max(0, (-slot.z - 1000) / 3000),
                        ),
                      } as CSSProperties
                    }
                  >
                    <div className="bs-hall__back" />
                    <div className="bs-hall__side bs-hall__side--l" />
                    <div className="bs-hall__side bs-hall__side--r" />
                    <div className="bs-hall__roof" />
                    {BOARD_TOPS.map((top) => (
                      <div
                        key={top}
                        className="bs-hall__board"
                        style={{ "--top": top - 90 } as CSSProperties}
                      />
                    ))}
                    {minis.map((row, r) => (
                      <div
                        key={r}
                        className="bs-hall__row"
                        style={{ "--top": ROW_TOPS[r] } as CSSProperties}
                      >
                        {row.spines.map((s) => (
                          <span
                            key={s.id}
                            className={`bs-hall__spine bs-cloth--${s.cloth}`}
                            style={
                              {
                                "--w": s.w,
                                "--h": s.h,
                                ...clothStyle({ cloth_color: s.color }),
                              } as CSSProperties
                            }
                          />
                        ))}
                      </div>
                    ))}
                    {c ? (
                      <button
                        type="button"
                        className="bs-hall__face"
                        aria-label={c.label}
                        tabIndex={nearing === null && !atDesk && !open ? 0 : -1}
                        onClick={() => approach(index)}
                      >
                        <Fronts plaque={c.plaque} minis={minis} />
                      </button>
                    ) : (
                      <span className="bs-hall__face" aria-hidden="true">
                        <Fronts plaque="" minis={minis} />
                      </span>
                    )}
                  </div>
                );
              })}
              {current === 0 && (
                <div className="bs-hall__desk">
                  <button
                    type="button"
                    className="bs-hall__desk-front"
                    aria-label={t("desk.title")}
                    tabIndex={atDesk ? -1 : 0}
                    onClick={() => setAtDesk(true)}
                    onMouseEnter={() => !atDesk && setTip("desk")}
                    onMouseLeave={() => setTip(null)}
                    onFocus={() => !atDesk && setTip("desk")}
                    onBlur={() => setTip(null)}
                  />
                  <div className="bs-hall__desk-top">
                    <button
                      type="button"
                      className="bs-hall__tool bs-hall__tool--catalog"
                      aria-label={t("hall.catalog")}
                      {...tool("catalog", onList)}
                    >
                      <span className="bs-hall__cards" />
                      <span className="bs-hall__pull" />
                    </button>
                    <button
                      type="button"
                      className="bs-hall__tool bs-hall__tool--card"
                      aria-label={t("hall.add")}
                      {...tool("add", onAdd)}
                    >
                      {t("hall.card")}
                      <span className="bs-hall__pen" />
                    </button>
                    <button
                      type="button"
                      className="bs-hall__tool bs-hall__tool--stamp"
                      aria-label={t("desk.tidy")}
                      disabled={atDesk && (disabled || busy)}
                      {...tool("tidy", tidy)}
                    >
                      <span className="bs-hall__knob" />
                    </button>
                    <span className="bs-hall__ink" aria-hidden="true" />
                    <button
                      type="button"
                      className="bs-hall__tool bs-hall__tool--glass"
                      aria-label={t("hall.find")}
                      {...tool("find", onFind)}
                    >
                      <span className="bs-hall__lens" />
                      <span className="bs-hall__handle" />
                    </button>
                  </div>
                  <div className="bs-hall__lamp" aria-hidden="true">
                    <span className="bs-hall__glow" />
                    <span className="bs-hall__shade" />
                    <span className="bs-hall__stem" />
                    <span className="bs-hall__foot" />
                  </div>
                </div>
              )}
            </div>
            {tip && (
              <div
                className="bs-hall__tip"
                role="tooltip"
                style={
                  {
                    "--x": TOOL_TIPS[tip].x,
                    "--y": TOOL_TIPS[tip].y,
                  } as CSSProperties
                }
              >
                <span className="bs-hall__tip-title">
                  {tip === "desk"
                    ? t("desk.title")
                    : tip === "tidy"
                      ? t("desk.tidy")
                      : t(`hall.${tip}`)}
                </span>
                <span className="bs-hall__tip-hint">
                  {t(`hall.${tip}Hint`)}
                </span>
              </div>
            )}
          </div>
        </div>
        {open && (
          <div
            className="bs-hall__stage"
            onPointerDown={(e) =>
              (downOnStage.current = e.target === e.currentTarget)
            }
            onClick={(e) =>
              e.target === e.currentTarget && downOnStage.current && leave()
            }
          >
            <Bookcase
              key={open.key}
              shelves={open.shelves}
              matches={matches}
              onOpen={onOpen}
              onMore={onMore}
              onMove={onMove}
            />
          </div>
        )}
      </div>
      {open ? null : atDesk ? (
        <div className="bs-hall__bar">
          <button
            type="button"
            className="bs-btn bs-btn--quiet"
            onClick={() => setAtDesk(false)}
          >
            <Chevron back />
            {t("hall.back")}
          </button>
          <p className="bs-hall__note" aria-live="polite">
            {note}
          </p>
        </div>
      ) : (
        <div className="bs-hall__bar">
          {pages > 1 && (
            <span className="bs-hall__steps">
              <button
                type="button"
                className="bs-btn bs-btn--quiet"
                disabled={current >= pages - 1}
                onClick={() => turn(current + 1)}
              >
                <Chevron back />
                {t("hall.earlier")}
              </button>
              <span className="bs-hall__range">{range}</span>
              <button
                type="button"
                className="bs-btn bs-btn--quiet"
                disabled={current === 0}
                onClick={() => turn(current - 1)}
              >
                {t("hall.later")}
                <Chevron />
              </button>
            </span>
          )}
          {pages > 1 && (
            <label className="bs-hall__year">
              {t("hall.year")}
              <select
                value=""
                onChange={(e) => {
                  const index = Number(e.target.value);
                  setPage(Math.floor(index / SLOTS.length));
                  setPicked(cases[index].key);
                }}
              >
                <option value="">{t("hall.pick")}</option>
                {cases.map((c, i) =>
                  i > 0 ? (
                    <option key={c.key} value={i}>
                      {c.plaque}
                    </option>
                  ) : null,
                )}
              </select>
            </label>
          )}
        </div>
      )}
    </div>
  );
}

function Fronts({ plaque, minis }: { plaque: string; minis: MiniShelf[] }) {
  return (
    <>
      {plaque && <span className="bs-hall__plaque">{plaque}</span>}
      {BOARD_TOPS.slice(1, 5).map((top, k) => (
        <span
          key={top}
          className="bs-hall__front"
          style={{ "--top": top - 50 } as CSSProperties}
        >
          {minis[k]?.label && (
            <span className="bs-hall__label">{minis[k].label}</span>
          )}
        </span>
      ))}
    </>
  );
}
