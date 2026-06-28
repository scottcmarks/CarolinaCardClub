# Poker Hand Logger

A mobile-first PWA for logging live poker hands fast: board, hero hole cards, and
showdown reveals — with a four-color deck, duplicate prevention, and a persistent,
editable hand history. Built to be opened from a phone home screen and used at the table.

## Quick start

```bash
npm install
npm run dev        # local dev server (open the printed URL on your phone, same Wi-Fi)
npm run build      # production build → dist/
npm run preview    # serve the production build locally
```

Requires Node 18+.

## Installing on a phone

The app is a PWA. After `npm run build && npm run preview` (or deploying `dist/`),
open it in mobile Safari/Chrome and choose **Add to Home Screen**. It then launches
full-screen, works offline, and keeps your data between sessions.

To use it live with no setup, deploy `dist/` to any static host (Netlify, Vercel,
GitHub Pages, Cloudflare Pages) and install from that URL.

## How it works

- **Board-first entry.** You start on the flop; tapping a rank reveals the four-color
  suit dock, and tapping a suit auto-advances to the next slot (flop → turn → river).
- **Hero cards are terminal.** Completing both hero hole cards ends the hand, saves it,
  and resets for the next one. You can also press **End hand** to save a board-only hand.
- **Reveals.** "+ Reveal" adds a villain's two-card showdown hand with an optional seat tag.
- **Session context.** Venue, table, and seat are set once and stamped onto every hand,
  along with an automatic timestamp.
- **Editable history.** The list button opens every saved hand; tap one to load it back,
  add reveals or fix cards, then **Update hand**. Auto-end is suppressed while editing.
- **Persistence.** Hands and session context are saved to `localStorage` and survive reload.
- **Export.** Copy the whole session as text, or download CSV for a spreadsheet/tracker.

## Project structure

```
src/
  constants.js            ranks, suits, streets, theme tokens
  lib/
    cards.js              pure card/board helpers (cardStr, boardStr, firstEmpty, …)
    storage.js            versioned localStorage load/save
    export.js             text + CSV serialization, file download
  hooks/
    useHandLogger.js      ALL state + actions (the brain). Persistence effects live here.
  components/
    SessionBar.jsx        venue/table/seat + history button
    Board.jsx             flop/turn/river/hero slot groups
    Reveals.jsx           villain reveals strip
    Keypad.jsx            rank grid + suit dock
    Actions.jsx           undo / clear / end-or-update
    StatusLine.jsx        contextual hint + flash messages
    HistoryPanel.jsx      browsable/editable/exportable log overlay
    Slot.jsx, Chip.jsx    shared card primitives
  App.jsx                 composition only — wires the hook to components
```

The architecture is deliberately split so logic (the hook) is decoupled from
presentation (components). Components are stateless except for trivial local UI toggles.

## Data model

A saved hand:

```js
{
  id: 7,
  ts: 1719600000000,            // Date.now() at save
  location: "Bellagio",
  table: "12",
  seat: "4",
  cards: [c,c,c, c, c, c,c],    // indices 0–2 flop, 3 turn, 4 river, 5–6 hero
  reveals: [{ seat: "2", cards: [c,c] }],
}
```

A card is `{ rank: "A", suit: "s" }`. Empty slots are `null`. Suit keys: `s h d c`.

## Roadmap / good next tasks

These are scoped, self-contained handoffs:

1. **Reducer refactor.** Move `useHandLogger`'s state to `useReducer` for stricter
   transitions and easier testing. Behavior should be identical.
2. **Per-hand context override.** Allow editing venue/table/seat on an individual saved
   hand (for table changes mid-session) without altering the live session.
3. **Tracker-specific export.** Add an exporter to match a chosen tool's format
   (PokerStars hand history, a specific CSV schema, etc.). See `lib/export.js`.
4. **Bigger-deck / non-holdem modes.** Omaha (4 hero cards), or a free-flow "next card"
   mode toggle for equity input.
5. **Session boundaries.** Track session start/end and per-hand duration; group the log
   by session.
6. **Cloud sync (optional).** Swap `lib/storage.js` for an IndexedDB + sync backend.
7. **Tests.** `lib/cards.js` and `lib/export.js` are pure and unit-testable; add Vitest.

## Notes for Claude Code

- State and side effects are centralized in `src/hooks/useHandLogger.js`. Start there.
- The auto-end rule lives in `pickSuit`: it only fires for a NEW hand when both hero
  slots fill. Editing an existing hand never auto-ends — that's intentional.
- `lib/` is pure and side-effect-free except `export.js`'s `download()` and
  `storage.js`'s localStorage access. Keep it that way.
- `gen_icons.py` regenerates the PWA icons (needs Pillow). Icons are committed, so you
  only need it if you change the artwork.
- Theme colors are in `constants.js` (`theme`). Felt green `#14342b`, brass `#C9A227`,
  card `#F6F3EA`.
