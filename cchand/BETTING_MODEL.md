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
  type ∈ post | straddle | fold | check | call | bet | raise | allin | street | reveal
  street ∈ preflop | flop | turn | river
```

- `post` — blind posted at hand start. SB and BB are seeded as posts so their chips
  are in the pot even if they later fold. Sets the opening `currentBet = bb`.
- `straddle` — a UTG-only forced blind raise, posted before the action; behaves like a
  post (raises `currentBet`, chips in the pot) but the straddler **acts last preflop**
  (the preflop actor-walk anchors on the *last* forced poster = the straddler, else the
  BB). Amount is site-dependent, from the table's rake profile `straddleAmounts` (one =
  automatic; several = the user picks; absent = no straddle). Danville 1-3 = fixed $5;
  Five Oaks 1-2 = $4 or $5. A quick "Straddle $N" button shows in the betting bar preflop
  before any voluntary action. *Non-UTG straddles and the Five Oaks "Round-of-Each" (RoE
  mixed game, ~$10 straddle) are future work.*
- `bet` / `raise` — `amount` is the **total this player has in for the street** ("raise
  to X"), not the increment. Increment to the pot = `amount − committedThisStreet`.
- `allin` — like bet/raise (`amount` = the resulting street total, computed upstream from
  the seat's stack, or typed when no stack is set) but also marks the seat **all-in**:
  it persists in `allInSet` (across streets — committed resets, all-in doesn't), and
  all-in seats are excluded from `needsAct`/`actor`. A short all-in (amount < currentBet)
  doesn't raise the bet. **Side pots are not modelled** — the total pot is all rake needs;
  side pots only matter for splitting winnings, which aren't logged yet.
- `call` — match `currentBet`. `check` — pass with nothing owed.
- `fold` — out; already-committed chips stay in the pot. We record the street so a fold
  in a *prior* street can be flagged (see Corrections).
- `street` — marks the transition that starts a new betting round (resets
  per-street commit + currentBet).

**All-in run-out:** when a betting round opens already-closed (everyone all-in),
`afterActionsChanged` (called from both a betting action and from board-completion in
`pickSuit`) detects `roundClosed` and advances straight to the next board / showdown — so
an all-in hand just walks through the remaining community cards with no action prompts.

**Stacks** are optional per-seat (`session.seats[i].stack`, set in setup). `!` on the
ActionPad commits `stack − totalCommitted`; with no stack it prompts for / uses a typed
amount. Stacks are user-maintained (not auto-updated by results).

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

Layout `7 8 9 / 4 5 6 / 1 2 3 / ✖ 0 ✓`, plus a `!` **all-in** button:
- digits accumulate an amount;
- `✖` (solid black, digit-sized) = **fold**;
- `✓` (large green check) = **check** if nothing owed, **call** if an amount is owed and
  no digits typed, or **bet/raise to** the typed amount;
- `!` = **all-in** (whole stack, or the typed amount if no stack is set);
- positioned so the bottom-row `0` sits under the finger: just over the next-to-act seat
  during normal stepping, or under the tapped seat when the user jumps ahead.

**Auto-fold-between:** tapping a seat *after* the current actor appends folds for every
pending seat in between, then makes the tapped seat the actor (keypad jumps to it).

**Corrections:** tapping a seat that folded **this** round reopens its action (removes
its current-street action; it becomes the actor again). A fold in a **prior** round can't
be corrected inline — the hand is flagged `fubar` and must be fixed in the offline editor.

## House charge — rake types (`lib/rake.js`)

`pot` = sum of all committed chips (derived). A rake profile has a **`type`**:

- **`percent`** — per-pot rake as a list of independently-capped `{percent, cap, shortCap?}`
  **components** (Danville: `[{10%,$7,short$5},{10%,$2}]`). Per hand:
  ```
  if (!sawFlop && dropOnFlopOnly) total = 0
  else total = Σ min(floor(pot·percent), (short ? shortCap : cap))     // short = playersDealt ≤ shortHandedThreshold
  ```
- **`time`** — per-seat time collection `{perHour, minHours, prepay?}`. **Per-hand rake is
  0**; the charge is a *session* cost via `computeTimeCharge`:
  `charge = prepaid ? prepay : max(minHours, ceil(elapsedHours)) · perHour`.
- **`none`** — no house cut.

Profiles live in a small **editable** localStorage table (`phl:rakes:v1`); `migrate()`
upgrades old flat-shape entries. Managed in-app via `RakeEditor` (add/edit/delete, pick
type). Seeds:
- `danville-1-3` = **Caesars Virginia (WSOP), Danville VA**, `percent`: 10%→$7 + 10%→$2,
  max $9/pot ($20→$4, $70+→$9); ≤5-handed rake cap $5 + no-flop-no-drop (user's
  recollection, unconfirmed online).
- `five-oaks` = **Five Oaks Club, Durham NC**, `time`: $6/hr, 2-hr min, $30 prepay
  (blinds placeholder $1/$2 — edit in setup).

## Session envelope + time charge

For a `time` venue the charge needs elapsed seated time, so a **session** has
`startedAt` / `endedAt` (`session`, persisted). Hybrid capture: auto-started at setup
(kept on re-setup), editable (±15 min) in the session sheet. `SessionClock` (header pill)
self-ticks and shows elapsed + the running metered charge for time venues; tapping it
opens `SessionSummary` — elapsed, hands-this-sitting (`ts ≥ startedAt`), per-pot rake
total, and (time venues) metered-vs-prepay with an **End session** / **Restart clock**
control. Per-hand timestamps (`ts`) remain a fallback bracket.

## Hero card concealment

Hero's hole cards render **face-down (backs)** in the ring. Tapping a filled hero card
toggles it face-up (and back). Reaching showdown auto-faces them. The hand records
`heroRevealed` so history/export note whether the table actually saw hero's cards. Hero
may also reveal retroactively via the offline editor.

## Reveals any time + the two-card rule (evaluator spec)

A shown/exposed card can be entered for **any seat at any point in the hand** — not just at
showdown (cards flash, get tabled, or are shown for all sorts of reasons). Player menu →
*Enter shown cards* starts reveal entry for that seat (hero → own hole slot; villain → a
reveal); completing both mid-hand returns to the action.

**To win a showdown a hand must show *two* cards.** So the eventual hand-evaluator (which
replaces the winner-tap scaffolding) considers **only seats with both hole cards entered**
as winner candidates, evaluates their best 5-of-7, and awards accordingly — a one-card or
mucked hand can't win. The two-card reveal is a **"twofer"**: it both records what was shown
*and* is the winner-determination input. Until the evaluator exists, the manual winner-tap
stands in (and remains afterward as the override for mucked/unknown hands).

## Result capture + stack settlement (auto-tracked stacks)

Stacks (`session.seats[i].stack`, optional) are **maintained by the engine**: chips leave
a seat as they're committed (already how `!` all-in computes the shove), and at hand end
`settleStacks` debits each seat its `totalCommitted` and credits the **winner** `pot − rake`
(`lib/betting.js`; net table change = −rake; untracked/null stacks untouched).

**Winner:** fold-to-one wins automatically. At a contested showdown the **hand evaluator**
(`lib/handeval.js`) reads the board + the shown hands and **auto-selects the winner(s)**
when entering `settling`; the banner shows the winning hand ("Winner: Flush"). The user
confirms with **Award**, or **taps a seat to override** — the tap survives only as the
override for **mucked / unknown hands** (only hands showing two cards compete; the two-card
rule). Chops select multiple seats and split with an odd-chip-to-lowest-seat rule.

`null` winner (skip) records the hand without settling. Each hand stores `winner` + `heroNet`
(`won − committed`); `SessionSummary` sums `heroNet` over the sitting = **hero P&L** (free
byproduct). Offline edits never re-settle. Manual `Set stack` (player menu) coexists —
add-ons and eyeball corrections override the auto-tracked number anytime.

## Live seating — player menu, seat change, stand-up

Tapping a seat's **name tag** opens `PlayerMenu` (anchored via `data-seat`): *Set stack*,
*Rename* (villain), and — hero — *Change seat* / *Stand up*; empty seat → *Seat a player*.
Occupancy/position changes go through `applySeating(newSeats, patch)` → `setSession` +
`resetWorking(button, newSeats)` (reseeds the between-hands hand's blinds/positions).

- **Change seat:** *Change seat* → `moving` mode; tap an open seat → `moveHeroTo` (hero's
  stack travels to the new seat, old seat opens).
- **Stand up:** hero vacates and goes `sittingOut` (seatless, not dealt in; `session.seat`
  is kept so the stack rests there); the table renders the seat empty. Tap any open seat →
  `heroSitDown` (stack moves to the chosen seat). *"Buy the button" on re-entry is parked.*
- Button/blinds already tolerate arbitrary/empty seats (dead button/SB), so a move or
  stand-up needs no special positioning logic.

## Persistence

- `session` (`phl:session:v1`): venue, table, heroName, seat, button, rakeProfileId,
  `seats:[{occupied,name,stack}]`, `onboarded`, `startedAt`/`endedAt`/`prepaid`, `sittingOut`.
- `log` (`phl:log:v1`): each saved hand adds `actions`, `pot`, `rake`, `winner`, `heroNet`,
  `heroRevealed`, `seats` snapshot (pre-settlement starting stacks), `button`, `blinds`.
- `rakes` (`phl:rakes:v1`): editable rake profiles (percent/time/none).

Old hands without these fields stay readable (treated as no-betting hands).
