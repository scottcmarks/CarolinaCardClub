# Poker Hand Logger — UI Redesign Handoff

Notes for continuing the keypad + table redesign in Claude.app. Hand-off written
mid-task (Claude Code paused right before installing Tailwind).

## Where the project lives / how to run

- Path: `~/carolina_card_club/poker-hand-logger/` (a subdir of the carolina_card_club repo).
- Node was just installed via Homebrew (`brew install node`) — Node 26.4.0 / npm 11.17.0.
  `npm`/`node` are at `/opt/homebrew/bin` (export PATH if a shell can't find them).
- Stack: **Vite 7 + React 18 + vite-plugin-pwa**. `npm run dev -- --host` then open the
  Network URL on a phone (same Wi-Fi). `npm run build` → `dist/`.
- Dependency state is clean: 0 vulnerabilities, clean from-scratch install. Pinned
  vite ^7.3.6 + @vitejs/plugin-react ^4.7.0 (do NOT go to vite 8 — plugin-react 4.7's
  peer range is vite ^4–7, and plugin-react-oxc is deprecated + needs rolldown-vite).

## ⚠️ Key discovery: Tailwind is NOT installed

The whole app is written with Tailwind utility classes (`flex`, `grid`, `gap-2`,
`justify-center`, `rounded-xl`, `active:scale-95`, etc.) but **Tailwind was never added**
— no `tailwindcss` dep, no `@tailwindcss/vite` plugin, no `@import "tailwindcss"` in
`index.css`, no config. So every utility class is **inert**.

This is the root cause of the user's complaint that the flop/turn/river buttons are
"crammed against the left margin": `justify-center` / `flex` do nothing, so layout falls
back to default block/inline flow. Card glyphs inside `Slot` aren't centered either
(`flex items-center justify-center` is inert).

### The intended next step (was about to run this, user paused it)

Install Tailwind v4 and wire it in — this repairs centering across the ENTIRE app
(SessionBar, Actions, StatusLine, HistoryPanel all currently degraded), then build the
redesign on top:

```bash
cd ~/carolina_card_club/poker-hand-logger
npm install -D tailwindcss @tailwindcss/vite
```

Then:
1. `vite.config.js` — add the plugin:
   ```js
   import tailwindcss from "@tailwindcss/vite";
   // plugins: [tailwindcss(), react(), VitePWA({...})]
   ```
2. `src/index.css` — add at the very top:
   ```css
   @import "tailwindcss";
   ```
   (keep the existing `.no-scrollbar` rule and base styles)
3. Verify: `npm audit` (expect 0 vulns), `npm run build`, then `npm run dev -- --host`.

Tailwind v4 auto-detects sources — no `tailwind.config.js` / `content` array needed.
`@tailwindcss/vite` supports Vite 7.

> Alternative if the user prefers NO new dependency: convert the touched components to
> pure inline styles instead. But Tailwind is the framework the code was written for, so
> installing it is the cleaner fix and repairs the other components for free.

## What the user asked for (the redesign)

Verbatim intent:
1. **Rank keypad**: bigger buttons, in a **3-row layout** `AKQJT / 98765 / 432`.
2. **Suit chooser**: they LIKE that it pops up right under the finger after tapping a
   rank — keep that, but make the **suit buttons larger**.
3. **Board (flop/turn/river)**: bigger buttons, **not crammed against the left margin**,
   centered, with spacing: `flop · [half-space] · turn · [half-space] · river`.
4. **Iconic table image**: the community cards sit in the **middle of an oval poker
   table**. The **hero's cards** appear at the **hero's seat position** (per the
   session's table/seat info; default **seat 2** if seat hasn't been set).
5. **Villain entry**: **active touch spots around the table** (the other seats) to enter
   villain showdown hands.

## Current architecture (read these first)

- `src/hooks/useHandLogger.js` — ALL state + actions ("the brain"). Persistence effects
  here. Card model: `cards` is a length-7 array — indices 0–2 flop, 3 turn, 4 river,
  5–6 hero hole (`HOLE_START = 5`). `reveals` is `[{ seat: "2", cards: [c,c] }]`.
  A card is `{ rank, suit }`; empty = `null`. Suit keys `s h d c`.
- `src/constants.js` — `RANKS`, `SUITS` (four-color), `STREETS`, `TOTAL`, `HOLE_START`,
  `theme`.
- `src/components/` — `SessionBar`, `Board`, `Reveals`, `Keypad`, `Actions`,
  `StatusLine`, `HistoryPanel`, `Slot`, `Chip`.
- `src/App.jsx` — composition. Currently renders `<Board>` + `<Reveals>` stacked.
- `src/lib/cards.js` — pure helpers (`sameTarget`, `firstEmpty`, `suitMeta`, etc.).

Auto-end rule (keep it): in `pickSuit`, completing BOTH hero hole cards on a NEW hand
saves the hand and resets. Editing an existing hand never auto-ends.

## Proposed implementation plan (designed, not yet applied)

### constants.js — add
```js
export const RANK_ROWS = [["A","K","Q","J","T"],["9","8","7","6","5"],["4","3","2"]];
export const SEAT_COUNT = 9;          // seats shown around the table
export const DEFAULT_HERO_SEAT = 2;   // when session.seat is blank
export const tableTheme = {
  rail: "#3a2a1a",                    // brown rail (tune to taste)
  feltOval: "radial-gradient(120% 90% at 50% 35%, #1f5446 0%, #163a30 55%, #0f2a22 100%)",
};
```

### hooks/useHandLogger.js — add a `selectSeat` action
Find-or-create a reveal tagged with a seat number, then select its first empty card.
Mirrors the existing `addReveal`/`removeReveal` setState-inside-updater pattern.
```js
const selectSeat = useCallback((seatNum) => {
  buzz(6);
  setPendingRank(null);
  const key = String(seatNum);
  setReveals((prev) => {
    const idx = prev.findIndex((r) => r.seat === key);
    if (idx >= 0) {
      const e = firstEmpty(prev[idx].cards);
      setActive({ type: "reveal", r: idx, c: e === null ? 0 : e });
      return prev;
    }
    const nr = [...prev, { seat: key, cards: [null, null] }];
    setActive({ type: "reveal", r: nr.length - 1, c: 0 });
    return nr;
  });
}, []);
// expose selectSeat in the returned object
```

### components/Keypad.jsx — rewrite (3 rows + anchored suit popover)
- Render `RANK_ROWS` as a 5-col CSS grid; give every button explicit
  `gridRow = rowIndex+1` and `gridColumn = (rowIndex===2 ? colIndex+2 : colIndex+1)` so
  the bottom row `4 3 2` is centered in columns 2–4. Buttons ~`height:58, fontSize:27,
  fontWeight:800`, gap 10.
- Suit chooser as a **fixed-position popover anchored to the tapped rank button**: on
  rank tap capture `e.currentTarget.getBoundingClientRect()`, store it in local state,
  render the 4 big suit buttons (~64×64) centered under the button. Clamp horizontally
  to viewport; flip above if it would overflow the bottom. A full-screen transparent
  backdrop dismisses (cancels pending). Hide the popover whenever `pendingRank` goes
  null (`useEffect`). This delivers "larger, right under my finger."
- Dup suits (already used `rank+suit`) are disabled/greyed, same as today.

### components/PokerTable.jsx — NEW (replaces Board + Reveals)
Props: `{ cards, reveals, active, heroSeat, onSelect, onSelectSeat, onRemoveReveal }`.
Layout = a `position:relative` container with `flex:1, minHeight:300`:
- **Felt oval**: absolutely positioned div, `inset:6`, `borderRadius:"50%"`,
  `background: tableTheme.feltOval`, `border: 8px solid tableTheme.rail`, inset shadow.
- **Community cards** (indices 0–4) centered (`left/top:50%`, translate -50%):
  flop trio (gap ~4) · 14px spacer · turn · 14px spacer · river. Card size ~`w34 h48`.
  Optional small FLOP/TURN/RIVER labels row beneath, widths matched to groups.
- **Seats** `1..SEAT_COUNT` placed on an ellipse. For seat n:
  ```js
  const a = Math.PI/2 + (n-1) * (2*Math.PI/SEAT_COUNT); // seat 1 bottom, clockwise
  const left = `${50 + 40*Math.cos(a)}%`;   // rx ≈ 40%
  const top  = `${50 + 38*Math.sin(a)}%`;   // ry ≈ 38%  (keeps nodes on-screen)
  ```
  - **Hero seat** (n === heroSeat): two hole-card slots (indices 5,6), gold accent,
    label "You · S{n}". Active when `active.type==="board" && active.index>=HOLE_START`.
  - **Villain seat with a reveal**: two card slots (reveal indices 0,1) + "S{n}" label +
    an `X` remove (calls `onRemoveReveal(revealIdx)`). Active when
    `active.type==="reveal" && reveals[active.r].seat===String(n)`.
  - **Empty villain seat**: a compact tappable chip (circle ~46px showing the seat
    number) → `onSelectSeat(n)` (creates the reveal and selects its first card).
- Reuse `Slot.jsx` for all card cells (pass `w`/`h`; it works once Tailwind is in).

Geometry notes (mobile, ~352px wide container): rx 40% / ry 38% keeps even expanded
side seats (≈72px) and the bottom hero node on-screen, and leaves a few px between the
far-left/right seats (3 and 8) and the community row when those seats hold reveals.
Tune if cards/seats overlap.

### App.jsx — wire it up
- Remove `Board` + `Reveals` imports/usage; import `PokerTable`.
- Compute hero seat:
  ```js
  const heroSeat = Math.min(Math.max(parseInt(h.session.seat,10) || DEFAULT_HERO_SEAT, 1), SEAT_COUNT);
  ```
- Render `<PokerTable cards={h.cards} reveals={h.reveals} active={h.active}
  heroSeat={heroSeat} onSelect={h.selectTarget} onSelectSeat={h.selectSeat}
  onRemoveReveal={h.removeReveal} />` where Board/Reveals were.
- Drop the old `<div className="flex-1" />` spacer; let PokerTable's `flex:1` fill the
  space (works once Tailwind makes the outer `flex flex-col` real).
- `Board.jsx` and `Reveals.jsx` become unused — delete them once PokerTable works.

## Verification checklist
- `npm run build` clean; `npm audit` → 0 vulns.
- `npm run dev -- --host`, load on phone (and/or desktop http://localhost:5173/).
- Rank pad is 3 rows AKQJT / 98765 / 432, big buttons; suit popover appears under the
  tapped rank, larger; dup suits greyed.
- Oval table with community cards centered (flop/turn/river with gaps), hero cards at
  hero's seat (default seat 2 when unset), other seats tappable to enter villain hands;
  completing both hero cards still auto-ends a new hand.
- Existing screens (SessionBar editor, History overlay, Actions row) now center
  correctly thanks to Tailwind.

## Git state
- On branch `main`. The hand-logger lives in commits:
  `c44a11e` (add PWA), `7419f27` (vite 8 bump — superseded), `a816510` (pin vite 7).
- Nothing for the redesign is committed yet. No source files were modified in this
  session beyond what's already committed; only this HANDOFF.md is new.
- A dev server may still be running in the background (vite on :5173).

## Open questions for the user
- Seat count: assumed **9**. Confirm the club's table size (8/9/10?).
- Seat numbering/orientation: assumed seat 1 at bottom-center, increasing clockwise.
  Confirm this matches how they think about seats, or whether hero should always be
  pinned to the bottom regardless of seat number.
- OK to add Tailwind as a dependency (recommended), or keep zero-new-deps via inline
  styles?
