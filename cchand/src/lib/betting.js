// Pure betting engine. The action log is the source of truth; this replays it
// into the derived round state (who's in, current bet, pot, whose turn).

import { occupiedSeats, blinds, nextOccupied } from "./positions.js";

export const STREETS_ORDER = ["preflop", "flop", "turn", "river"];

// Seed the blind posts for the start of a hand. Returns [] if <2 players.
// `bringIn` (e.g. Danville 2-2-5 PLO): a MANDATORY UTG post that acts like a
// straddle — it sets the preflop bet, and the poster gets the last option.
// Seeded as type "straddle" (the engine already gives the last forced poster
// the option) with `seeded: true` so the blinds-seed effect can tell it apart
// from a voluntary straddle. Skipped heads-up (no seat behind the blinds).
export function seedPosts(seats, button, sbAmt, bbAmt, bringIn) {
  const b = blinds(seats, button);
  if (!b) return [];
  const posts = [
    { seat: b.sb, street: "preflop", type: "post", amount: sbAmt },
    { seat: b.bb, street: "preflop", type: "post", amount: bbAmt },
  ];
  if (bringIn) {
    const utg = nextOccupied(seats, b.bb);
    if (utg != null && utg !== b.sb && utg !== b.bb)
      posts.push({ seat: utg, street: "preflop", type: "straddle", amount: bringIn, seeded: true });
  }
  return posts;
}

// Replay the action log into derived state.
//   actions  chronological action log (incl. blind posts + street markers)
//   ctx      { seats, button }
export function reduceBetting(actions, ctx) {
  const { seats, button } = ctx;
  const bbAmt = ctx.bb ?? 0;
  const occ = occupiedSeats(seats);
  const stackOf = (seat) => {
    const s = seats[seat - 1];
    return s && typeof s.stack === "number" ? s.stack : null;
  };
  const inHand = new Set(occ);
  const allInSet = new Set(); // seats with no chips left — still in, can't act
  const foldedStreet = {};
  const committed = {}; // chips this street
  const totalCommitted = {}; // chips all streets (pot share)
  occ.forEach((s) => {
    committed[s] = 0;
    totalCommitted[s] = 0;
  });

  let street = "preflop";
  let currentBet = 0;
  let lastAggressor = null;
  let lastActor = null;
  let lastRaiseSize = bbAmt; // size of the last full raise (min legal raise increment)
  const actedThisStreet = new Set();
  const actedSinceRaise = new Set(); // voluntary actors since the last FULL raise (re-raise rights)

  const startStreet = (st) => {
    street = st;
    currentBet = 0;
    lastAggressor = null;
    lastActor = null;
    lastRaiseSize = bbAmt;
    actedThisStreet.clear();
    actedSinceRaise.clear();
    occ.forEach((s) => (committed[s] = 0));
  };

  for (const a of actions || []) {
    const { seat, type, amount } = a;
    if (type === "street") {
      startStreet(a.street);
      continue;
    }
    if (type === "post" || type === "straddle") {
      // forced blinds + straddles. The last one posted (BB, or a straddler) is
      // the "aggressor" and gets the last preflop action / option.
      committed[seat] = (committed[seat] || 0) + amount;
      totalCommitted[seat] = (totalCommitted[seat] || 0) + amount;
      if (committed[seat] > currentBet) {
        currentBet = committed[seat];
        lastRaiseSize = currentBet; // the top blind/straddle sets the "bet" to raise over
      }
      lastAggressor = seat;
      continue;
    }
    if (type === "reveal") continue; // showdown markers don't affect betting
    if (!inHand.has(seat)) continue; // defensive: stale ref

    if (type === "fold") {
      inHand.delete(seat);
      foldedStreet[seat] = street;
      actedThisStreet.add(seat);
      lastActor = seat;
    } else if (type === "check") {
      actedThisStreet.add(seat);
      actedSinceRaise.add(seat);
      lastActor = seat;
    } else if (type === "call") {
      // A caller can only put in what they have left; calling for more than the
      // remaining stack is an all-in for less (a side pot forms).
      let add = Math.max(0, currentBet - (committed[seat] || 0));
      const st = stackOf(seat);
      if (st != null) add = Math.min(add, Math.max(0, st - (totalCommitted[seat] || 0)));
      committed[seat] += add;
      totalCommitted[seat] += add;
      actedThisStreet.add(seat);
      actedSinceRaise.add(seat);
      lastActor = seat;
    } else if (type === "bet" || type === "raise") {
      const to = amount;
      const inc = to - currentBet;
      const add = Math.max(0, to - (committed[seat] || 0));
      committed[seat] = to;
      totalCommitted[seat] += add;
      if (to > currentBet) {
        if (inc >= lastRaiseSize) {
          lastRaiseSize = inc; // a full raise reopens the betting…
          actedSinceRaise.clear();
        }
        currentBet = to;
        lastAggressor = seat;
      }
      actedThisStreet.add(seat);
      actedSinceRaise.add(seat);
      lastActor = seat;
    } else if (type === "allin") {
      // amount = this-street total the player is all-in for (computed upstream
      // from their stack, or typed). May be a full raise or a short call.
      const to = amount;
      const inc = to - currentBet;
      const add = Math.max(0, to - (committed[seat] || 0));
      committed[seat] = Math.max(committed[seat] || 0, to);
      totalCommitted[seat] += add;
      if (to > currentBet) {
        if (inc >= lastRaiseSize) {
          lastRaiseSize = inc; // a full-raise all-in reopens…
          actedSinceRaise.clear();
        }
        // a short all-in (inc < lastRaiseSize) raises the call but does NOT reopen
        currentBet = to;
        lastAggressor = seat;
      }
      actedThisStreet.add(seat);
      actedSinceRaise.add(seat);
      allInSet.add(seat); // persists across streets (committed resets, this doesn't)
      lastActor = seat;
    }
  }

  // Any in-hand player whose committed chips reach their tracked stack is all-in,
  // however they got there — a plain "call" or "bet" for the last chip counts,
  // not just the all-in button. Without this the lone big stack looks like it
  // still has someone to bet into and gets wrongly offered action on later
  // streets when everyone else is already all-in.
  occ.forEach((seat) => {
    const st = stackOf(seat);
    if (inHand.has(seat) && st != null && (totalCommitted[seat] || 0) >= st)
      allInSet.add(seat);
  });

  // Live pot = all chips on the table (raw). Uncalled bets are only returned at
  // hand end — see contestedPot(), used for rake + the recorded pot.
  const pot = occ.reduce((s, seat) => s + (totalCommitted[seat] || 0), 0);

  const needsAct = (seat) =>
    inHand.has(seat) &&
    !allInSet.has(seat) && // all-in players are done acting
    (!actedThisStreet.has(seat) || (committed[seat] || 0) < currentBet);

  // Betting is only live if 2+ players still have chips, OR the lone chip-holder
  // still owes a call to an all-in. Otherwise the hand just runs out the board.
  const liveWithChips = occ.filter((s) => inHand.has(s) && !allInSet.has(s));
  const bettingPossible =
    liveWithChips.length > 1 ||
    liveWithChips.some((s) => (committed[s] || 0) < currentBet);
  const anyNeeds = bettingPossible && occ.some(needsAct);
  let actor = null;
  if (anyNeeds && inHand.size > 1) {
    const b = blinds(seats, button);
    const anchor =
      lastActor != null
        ? lastActor
        : street === "preflop"
        ? lastAggressor ?? (b ? b.bb : button) // preflop: walk from the last blind/straddle (BB, or straddler)
        : button; // postflop: walk from button so SB is first
    const n = seats.length;
    for (let k = 1; k <= n; k++) {
      const seat = ((anchor - 1 + k) % n) + 1;
      if (needsAct(seat)) {
        actor = seat;
        break;
      }
    }
  }

  return {
    street,
    inHand: [...inHand],
    allIn: [...allInSet],
    foldedStreet,
    committed,
    totalCommitted,
    currentBet,
    pot,
    actor,
    lastAggressor,
    playersLeft: inHand.size,
    roundClosed: !anyNeeds || inHand.size <= 1,
    lastRaiseSize,
    minRaiseTo: currentBet + lastRaiseSize, // smallest legal raise-to
    // whether the current actor may (re-)raise: they may unless they've already
    // acted since the last FULL raise (i.e. they face only a short all-in).
    reraiseAllowed: actor == null || !actedSinceRaise.has(actor),
  };
}

// Pot-limit maximum raise-to for the current actor: call, then raise BY the
// pot after the call. maxTo = currentBet + (pot + toCall). (2-2 with a $5
// bring-in: pot $9, to-call $5 ⇒ "pot" opens to $19.)
export function potLimitMaxTo(state, seat = state.actor) {
  const owe = Math.max(0, state.currentBet - (state.committed[seat] || 0));
  return state.currentBet + state.pot + owe;
}

// Legality of a proposed bet/raise for the current actor. Returns a reason
// string if it appears ILLEGAL (min-raise / reopening / pot-limit rules),
// else null. The app never blocks — it uses this to gate the action behind an
// explained "are you sure?" override. All-in / call / check / fold are always
// legal (an all-in over the pot-limit max is checked upstream).
export function raiseLegality(state, type, amount, bb, opts = {}) {
  if (type !== "bet" && type !== "raise") return null;
  if (!state.reraiseAllowed) {
    return (
      "The last all-in was less than a full raise, so it does not reopen the " +
      "betting — players who already acted may only call or fold, not raise."
    );
  }
  if (state.currentBet === 0) {
    if (bb && amount < bb) return `A bet must be at least the big blind ($${bb}).`;
  } else if (amount < state.minRaiseTo) {
    return (
      `The minimum raise is to $${state.minRaiseTo} — a raise must be at least ` +
      `the size of the last raise ($${state.lastRaiseSize}).`
    );
  }
  if (opts.potLimit) {
    const maxTo = potLimitMaxTo(state);
    if (amount > maxTo)
      return (
        `Pot limit: the maximum ${state.currentBet ? "raise is to" : "bet is"} ` +
        `$${maxTo} (call + pot). $${amount} is over the pot.`
      );
  }
  return null;
}

const STREET_ABBR = { preflop: "PF", flop: "F", turn: "T", river: "R" };

// Compact human summary of an action log, grouped by street.
// e.g. "PF: S5 raise 9, S7 call, S1 fold | F: S5 bet 12, S7 fold"
export function actionsSummary(actions) {
  if (!actions || !actions.length) return "";
  const parts = [];
  let cur = "preflop";
  let line = [];
  const flush = () => {
    if (line.length) parts.push(`${STREET_ABBR[cur] || cur}: ${line.join(", ")}`);
    line = [];
  };
  for (const a of actions) {
    if (a.type === "street") {
      flush();
      cur = a.street;
      continue;
    }
    if (a.type === "reveal" || a.type === "post") continue;
    line.push(`S${a.seat} ${a.type}${a.amount != null ? " " + a.amount : ""}`);
  }
  flush();
  return parts.join(" | ");
}

// The pot that's actually contested at hand end: a lone top (uncalled) bet is
// capped at the second-highest contribution; the excess returns to the bettor.
// Used for rake + the recorded pot (distributePots returns the excess in stacks).
export function contestedPot(totalCommitted) {
  const vals = Object.values(totalCommitted).map((v) => v || 0);
  const max1 = vals.length ? Math.max(...vals) : 0;
  const atMax = vals.filter((v) => v === max1).length;
  const below = vals.filter((v) => v < max1);
  const ceiling = atMax >= 2 ? max1 : below.length ? Math.max(...below) : 0;
  return vals.reduce((a, v) => a + Math.min(v, ceiling), 0);
}

// Distribute the pot into layered (side) pots by contribution level and award
// each layer to whichever winners are eligible for it (contributed to it).
// Handles side pots (all-in for less) AND split/chopped pots. Uncalled excess
// returns to the sole top contributor as its own single-eligible layer.
// Returns { winnings: {seat: chips}, unresolved } — winnings sum to the full
// pot; `unresolved` is true if some layer had no eligible winner (its chips are
// returned to that layer's contributors, and the caller should warn).
export function distributePots(totalCommitted, winners) {
  const seats = Object.keys(totalCommitted)
    .map(Number)
    .filter((s) => (totalCommitted[s] || 0) > 0);
  const levels = [...new Set(seats.map((s) => totalCommitted[s]))].sort((a, b) => a - b);
  const winSet = new Set(winners || []);
  const winnings = {};
  let prev = 0;
  let unresolved = false;
  for (const lvl of levels) {
    const contributors = seats.filter((s) => totalCommitted[s] >= lvl);
    const layer = (lvl - prev) * contributors.length;
    const elig = contributors.filter((s) => winSet.has(s)).sort((a, b) => a - b);
    if (elig.length) {
      const share = Math.floor(layer / elig.length);
      const rem = layer - share * elig.length;
      elig.forEach((w) => (winnings[w] = (winnings[w] || 0) + share));
      for (let i = 0; i < rem; i++) winnings[elig[i % elig.length]] += 1; // odd chip → lowest seat
    } else {
      unresolved = true; // no designated winner for this layer — return it
      contributors.forEach((c) => (winnings[c] = (winnings[c] || 0) + (lvl - prev)));
    }
    prev = lvl;
  }
  return { winnings, unresolved };
}

// Subtract the rake from `winnings`, borne by `winners` proportionally to
// their gross. Mutates a copy; returns it.
function applyRake(winnings, winners, rake) {
  const out = { ...winnings };
  const gross = (winners || []).reduce((a, w) => a + (winnings[w] || 0), 0);
  if (rake > 0 && gross > 0) {
    const ws = (winners || []).filter((w) => (winnings[w] || 0) > 0).sort((a, b) => winnings[b] - winnings[a]);
    let left = rake;
    ws.forEach((w) => {
      const take = Math.min(out[w], Math.floor((rake * winnings[w]) / gross));
      out[w] -= take;
      left -= take;
    });
    for (let i = 0; i < ws.length && left > 0; i++) {
      const take = Math.min(out[ws[i]], left);
      out[ws[i]] -= take;
      left -= take;
    }
  }
  return out;
}

// Rake-adjusted winnings: winners bear the rake proportionally to their gross.
export function settleResult(totalCommitted, winners, rake) {
  const { winnings, unresolved } = distributePots(totalCommitted, winners);
  return { winnings: applyRake(winnings, winners, rake), unresolved };
}

// Double-board settlement: each board is worth half the pot (side-pot layers
// included), so run the layered distribution once per board's winners and
// average the two, integer-safe (leftover odd dollars go to the lowest seats
// that had an odd combined total — the "odd chip" rule, in dollars).
export function settleResultBoards(totalCommitted, winnersA, winnersB, rake) {
  const A = distributePots(totalCommitted, winnersA);
  const B = distributePots(totalCommitted, winnersB);
  const seats = new Set([...Object.keys(A.winnings), ...Object.keys(B.winnings)].map(Number));
  const combined = {};
  let paid = 0;
  let pot = 0;
  seats.forEach((s) => {
    const raw = (A.winnings[s] || 0) + (B.winnings[s] || 0);
    combined[s] = Math.floor(raw / 2);
    paid += combined[s];
    pot += raw;
  });
  pot = Math.round(pot / 2); // A and B each sum to the full pot
  const odd = [...seats]
    .filter((s) => ((A.winnings[s] || 0) + (B.winnings[s] || 0)) % 2 === 1)
    .sort((a, b) => a - b);
  for (let i = 0; paid < pot && i < odd.length; i++, paid++) combined[odd[i]] += 1;
  const winners = [...new Set([...(winnersA || []), ...(winnersB || [])])];
  return {
    winnings: applyRake(combined, winners, rake),
    unresolved: A.unresolved || B.unresolved,
  };
}

// Settle stacks after a hand: newStack = stack − committed + winnings. Seats
// with a null stack (untracked) are left untouched. `winnersB` (second-board
// winners) switches to the double-board split.
export function settleStacks(seats, state, winners, rake, winnersB) {
  const { winnings } = winnersB
    ? settleResultBoards(state.totalCommitted, winners, winnersB, rake)
    : settleResult(state.totalCommitted, winners, rake);
  return seats.map((s, i) => {
    const n = i + 1;
    if (!s || s.stack == null) return s;
    const committed = state.totalCommitted[n] || 0;
    const won = winnings[n] || 0;
    if (committed === 0 && won === 0) return s;
    return { ...s, stack: Math.max(0, s.stack - committed + won) };
  });
}

// Chips a seat must put in to call the current bet.
export const toCall = (state, seat) =>
  Math.max(0, state.currentBet - (state.committed[seat] || 0));

// Suggested minimum legal raise-to (not enforced — a hint for the pad).
export const minRaiseTo = (state, bbAmt) =>
  state.currentBet > 0 ? state.currentBet * 2 : bbAmt;
