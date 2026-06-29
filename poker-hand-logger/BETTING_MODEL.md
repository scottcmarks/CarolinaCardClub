# Betting / pot / rake model

Design notes for the "round of play" expansion. The logger went from *record the
cards* to *record the play*: seat identity, betting actions, pot, rake, and hero
card concealment.

## Source of truth

A hand's betting is a **chronological action log**; everything else (who's still in,
current bet, pot, whose turn) is **derived** by replaying it (`lib/betting.js
→ reduceBetting`). This makes undo/correction trivial: edit or truncate the log and
re-derive.

```
action = { seat, street, type, amount? }
  type ∈ post | fold | check | call | bet | raise | street | reveal
  street ∈ preflop | flop | turn | river
```

- `post` — blind posted at hand start. SB and BB are seeded as posts so their chips
  are in the pot even if they later fold. Sets the opening `currentBet = bb`.
- `bet` / `raise` — `amount` is the **total this player has in for the street** ("raise
  to X"), not the increment. Increment to the pot = `amount − committedThisStreet`.
- `call` — match `currentBet`. `check` — pass with nothing owed.
- `fold` — out; already-committed chips stay in the pot. We record the street so a fold
  in a *prior* street can be flagged (see Corrections).
- `street` — marks the transition that starts a new betting round (resets
  per-street commit + currentBet).

## Order, blinds, positions (`lib/positions.js`)

Seats are `1..N`. Clockwise = increasing seat number (matches the table layout: seat 1
to the dealer's left, increasing around). The **button** (`session.button`) is the seat
holding the dealer button; it advances +1 (skipping nobody — dead button allowed) each
saved hand.

- SB = next occupied seat after button; BB = next occupied after SB; UTG = next occupied
  after BB (= "SB+2"). Heads-up (2 players): button **is** the SB; the other is BB.
- Preflop action starts at UTG and ends with the BB's option. Post-flop action starts at
  the first occupied seat after the button (SB).
- Empty/vacated seats are skipped everywhere.

## Phase machine (the hook)

A hand interleaves **betting rounds** with **card entry**:

```
preflop-bet ──round closes (≥2 left)──▶ deal FLOP (3 cards) ──▶ flop-bet
   │                                                               │
   └─ everyone folds to one player ─▶ hand ends (NO flop ⇒ no drop)│
flop-bet ─▶ deal TURN ─▶ turn-bet ─▶ deal RIVER ─▶ river-bet ─▶ SHOWDOWN ─▶ end
```

- A betting round is **closed** when no in-hand seat still needs to act (everyone has
  matched `currentBet` and each has had a turn since the last aggressor; the BB gets the
  preflop option).
- When a round closes with one player left, the hand ends immediately. `sawFlop` (= flop
  cards present) drives whether a drop is taken.
- `mode` toggles `betting` ⇆ `cards`. In `cards` mode the rank keypad + suit popover are
  active and you tap card slots; in `betting` mode the ActionPad is active.

## ActionPad (`components/ActionPad.jsx`)

Layout `7 8 9 / 4 5 6 / 1 2 3 / ✖ 0 ✓`:
- digits accumulate an amount;
- `✖` (solid black, digit-sized) = **fold**;
- `✓` (large green check) = **check** if nothing owed, **call** if an amount is owed and
  no digits typed, or **bet/raise to** the typed amount;
- positioned so the bottom-row `0` sits under the finger: just over the next-to-act seat
  during normal stepping, or under the tapped seat when the user jumps ahead.

**Auto-fold-between:** tapping a seat *after* the current actor appends folds for every
pending seat in between, then makes the tapped seat the actor (keypad jumps to it).

**Corrections:** tapping a seat that folded **this** round reopens its action (removes
its current-street action; it becomes the actor again). A fold in a **prior** round can't
be corrected inline — the hand is flagged `fubar` and must be fixed in the offline editor.

## Pot & rake (`lib/rake.js`)

`pot` = sum of all committed chips (derived). Rake is computed at hand end:

```
rake = sawFlop || !dropOnFlopOnly
     ? (capIncludesDrop ? min(drop + floor(pot·pct), cap)
                        : drop + min(floor(pot·pct), cap))
     : 0
cap  = playersDealt ≤ shortHandedThreshold ? shortHandedCap : rakeCap
```

Rake profiles live in a small **editable** localStorage table (`phl:rakes:v1`), keyed by
id. Seeded entry `danville-1-3` (Danville $1/$3): drop $2, 10%, $7 cap, short-handed
(≤5 dealt) cap $5, no-flop-no-drop. **These seed numbers are the user's stated values and
a pending web-research check; because the table is user-editable in-app, an unconfirmed
default is acceptable and easily corrected.**

## Hero card concealment

Hero's hole cards render **face-down (backs)** in the ring. Tapping a filled hero card
toggles it face-up (and back). Reaching showdown auto-faces them. The hand records
`heroRevealed` so history/export note whether the table actually saw hero's cards. Hero
may also reveal retroactively via the offline editor.

## Persistence

- `session` (`phl:session:v1`): venue, table, heroName, heroSeat, button, rakeProfileId,
  `seats:[{occupied,name}]`, `onboarded`.
- `log` (`phl:log:v1`): each saved hand adds `actions`, `pot`, `rake`, `heroRevealed`,
  `seats` snapshot, `button`, `blinds`, `fubar`.
- `rakes` (`phl:rakes:v1`): editable rake profiles.

Old hands without these fields stay readable (treated as no-betting hands).
