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
import { hash } from "@/lib/cloth";
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

type HallCase = {
  key: string;
  plaque: string;
  label: string;
  shelves: Shelf[];
};
type Near = { index: number; vars: CSSProperties; snap: boolean };

const SCENE_W = 1200;
const SCENE_H = 724;
const DEPTH = 900;
const EYE_Y = SCENE_H * 0.45;
const FLOOR_Y = 640;
const MARGIN = 24;
const BOX_W = 300;
const CASE_W = 480;
const CASE_PADDING = 24;
const MIN_ROWS = 2;
const SLOTS = [
  { x: 290, z: -150, phi: 28 },
  { x: 910, z: -150, phi: -28 },
  { x: 340, z: -1000, phi: 40 },
  { x: 860, z: -1000, phi: -40 },
  { x: 340, z: -1560, phi: 40 },
  { x: 860, z: -1560, phi: -40 },
  { x: 340, z: -2120, phi: 40 },
];
const APPROACH_MS = 950;
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

const ignore = () => {};

function decorShelf(seed: number): Shelf {
  const h = (n: number) => hash(`${seed}:${n}`);
  const count = 6 + (h(0) % 14);
  const books = Array.from({ length: count }, (_, i): BookSummary => {
    const v = h(i + 1);
    return {
      id: `decor-${seed}-${i}`,
      title: "",
      author: null,
      original_title: null,
      language: null,
      year: null,
      page_count: 150 + (v % 600),
      audio_minutes: null,
      cover_url: null,
      cloth: CLOTHS[(v >>> 8) % CLOTHS.length],
      shelf: "no_date",
      editions: [],
    };
  });
  return { key: "no_date", count, books };
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
  const [near, setNear] = useState<Near | null>(null);
  const [openedKey, setOpenedKey] = useState<string | null>(null);
  const [atDesk, setAtDesk] = useState(false);
  const [tip, setTip] = useState<Tip | null>(null);
  const timer = useRef(0);
  const frame = useRef(0);
  const boxes = useRef(new Map<number, HTMLDivElement>());
  const downOnStage = useRef(false);
  useEffect(
    () => () => {
      window.clearTimeout(timer.current);
      cancelAnimationFrame(frame.current);
    },
    [],
  );

  const caseWidth = Math.round(Math.min(CASE_W, SCENE_W * scale - 32));
  const zoom = BOX_W / caseWidth;

  const cases = useMemo<HallCase[]>(() => {
    const [now, want, ...rest] = shelves;
    return [
      {
        key: "now",
        plaque: "",
        label: `${shelfLabel(t, now.key)}, ${shelfLabel(t, want.key)}`,
        shelves: [now, want],
      },
      ...rest.map((s) => ({
        key: s.key,
        plaque: shelfLabel(t, s.key),
        label: t("hall.case", { label: shelfLabel(t, s.key), count: s.count }),
        shelves: [s],
      })),
    ];
  }, [shelves, t]);

  const pages = Math.ceil(cases.length / SLOTS.length);
  const current = Math.min(page, pages - 1);
  const slots = SLOTS.map((slot, i) => ({
    slot,
    index: current * SLOTS.length + i,
  }));
  const decor = useMemo(
    () => SLOTS.map((_, i) => [decorShelf(current * SLOTS.length + i)]),
    [current],
  );
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
  const open = opened >= 0 ? cases[opened] : undefined;

  const nearVars = (index: number): CSSProperties => {
    const height = boxes.current.get(index)?.offsetHeight ?? 0;
    const grow = caseWidth / (BOX_W * scale);
    const tall = height * grow;
    const bottom =
      tall + 2 * MARGIN <= SCENE_H ? SCENE_H - MARGIN : MARGIN + tall;
    return {
      "--x": SCENE_W / 2,
      "--y": EYE_Y + (bottom - EYE_Y) / grow,
      "--z": DEPTH - DEPTH / grow,
      "--phi": 0,
    } as CSSProperties;
  };

  const approach = (index: number) => {
    if (near || open || atDesk) return;
    const key = cases[index].key;
    setTip(null);
    if (reduced) return setOpenedKey(key);
    setNear({ index, vars: nearVars(index), snap: false });
    timer.current = window.setTimeout(() => setOpenedKey(key), APPROACH_MS);
  };

  const leave = () => {
    if (!open) return;
    if (reduced) {
      setNear(null);
      return setOpenedKey(null);
    }
    setNear({ index: opened, vars: nearVars(opened), snap: true });
    setOpenedKey(null);
    frame.current = requestAnimationFrame(() => {
      frame.current = requestAnimationFrame(() => setNear(null));
    });
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

  const earlier = open && cases[opened + 1];
  const later = open && opened > 0 ? cases[opened - 1] : undefined;
  const state = [
    near && !open && "is-nearing",
    open && "is-open",
    atDesk && "is-desk",
  ]
    .filter(Boolean)
    .join(" ");
  const still = !near && !open && !atDesk;

  return (
    <div ref={hall} className={`bs-hall ${state}`}>
      <div
        ref={ref}
        className="bs-hall__frame"
        style={{ "--k": scale } as CSSProperties}
      >
        <div
          className="bs-hall__room"
          aria-hidden={open ? true : undefined}
          inert={!!open}
        >
          <div className="bs-hall__scene">
            <img className="bs-hall__backdrop" src={hallImage} alt="" />
            <div className="bs-hall__dim" />
            <div className="bs-hall__world" key={current}>
              {current === 0 && (
                <div className="bs-hall__window" aria-hidden="true" />
              )}
              {slots.map(({ slot, index }, i) => {
                const c = cases[index];
                const close = near?.index === index;
                const className = [
                  "bs-hall__box",
                  !c && "bs-hall__box--decor",
                  close && "is-near",
                  close && near.snap && "is-snap",
                  slot.z < -500 && "is-far",
                  c && (picked === c.key || matched(c)) && "is-picked",
                ]
                  .filter(Boolean)
                  .join(" ");
                return (
                  <div
                    key={index}
                    ref={(el) => {
                      if (el) boxes.current.set(index, el);
                      else boxes.current.delete(index);
                    }}
                    className={className}
                    style={
                      close
                        ? near.vars
                        : ({
                            "--x": slot.x,
                            "--y": FLOOR_Y,
                            "--z": slot.z,
                            "--phi": slot.phi,
                            "--haze": Math.min(
                              0.5,
                              Math.max(0, (-slot.z - 1000) / 3000),
                            ),
                          } as CSSProperties)
                    }
                  >
                    <div className="bs-hall__back" />
                    <div className="bs-hall__side bs-hall__side--l" />
                    <div className="bs-hall__side bs-hall__side--r" />
                    <div className="bs-hall__roof" />
                    <div
                      className="bs-hall__copy"
                      style={{ width: caseWidth, zoom }}
                      aria-hidden="true"
                      inert
                    >
                      <Bookcase
                        shelves={c ? c.shelves : decor[i]}
                        matches={matches}
                        onOpen={ignore}
                        width={caseWidth - CASE_PADDING}
                        minRows={MIN_ROWS}
                      />
                    </div>
                    <div className="bs-hall__haze" />
                    {c?.plaque && (
                      <span className="bs-hall__plaque" aria-hidden="true">
                        {c.plaque}
                      </span>
                    )}
                    {c && (
                      <button
                        type="button"
                        className="bs-hall__face"
                        aria-label={c.label}
                        tabIndex={still ? 0 : -1}
                        onClick={() => approach(index)}
                      />
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
            <div className="bs-hall__open" style={{ width: caseWidth }}>
              <Bookcase
                key={open.key}
                shelves={open.shelves}
                matches={matches}
                onOpen={onOpen}
                onMore={onMore}
                onMove={onMove}
                width={caseWidth - CASE_PADDING}
                minRows={MIN_ROWS}
              />
            </div>
          </div>
        )}
      </div>
      {open ? (
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
      ) : atDesk ? (
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
