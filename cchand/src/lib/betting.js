// Pure betting engine. The action log is the source of truth; this replays it
// into the derived round state (who's in, current bet, pot, whose turn).

import { occupiedSeats, blinds } from "./positions.js";

export const STREETS_ORDER = ["preflop", "flop", "turn", "river"];

// Seed the two blind posts for the start of a hand. Returns [] if <2 players.
export function seedPosts(seats, button, sbAmt, bbAmt) {
  const b = blinds(seats, button);
  if (!b) return [];
  return [
    { seat: b.sb, street: "preflop", type: "post", amount: sbAmt },
    { seat: b.bb, street: "preflop", type: "post", amount: bbAmt },
  ];
}

// Replay the action log into derived state.
//   actions  chronological action log (incl. blind posts + street markers)
//   ctx      { seats, button }
export function reduceBetting(actions, ctx) {
  const { seats, button } = ctx;
  const occ = occupiedSeats(seats);
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
  const actedThisStreet = new Set();

  const startStreet = (st) => {
    street = st;
    currentBet = 0;
    lastAggressor = null;
    lastActor = null;
    actedThisStreet.clear();
    occ.forEach((s) => (committed[s] = 0));
  };

  for (const a of actions || []) {
    const { seat, type, amount } = a;
    if (type === "street") {
      startStreet(a.street);
      continue;
    }
    if (type === "post") {
      committed[seat] = (committed[seat] || 0) + amount;
      totalCommitted[seat] = (totalCommitted[seat] || 0) + amount;
      currentBet = Math.max(currentBet, committed[seat]);
      lastAggressor = seat; // BB closes the preflop option
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
      lastActor = seat;
    } else if (type === "call") {
      const add = Math.max(0, currentBet - (committed[seat] || 0));
      committed[seat] += add;
      totalCommitted[seat] += add;
      actedThisStreet.add(seat);
      lastActor = seat;
    } else if (type === "bet" || type === "raise") {
      const to = amount;
      const add = Math.max(0, to - (committed[seat] || 0));
      committed[seat] = to;
      totalCommitted[seat] += add;
      currentBet = Math.max(currentBet, to);
      lastAggressor = seat;
      actedThisStreet.add(seat);
      lastActor = seat;
    } else if (type === "allin") {
      // amount = this-street total the player is all-in for (computed upstream
      // from their stack, or typed). May be a full raise or a short call.
      const to = amount;
      const add = Math.max(0, to - (committed[seat] || 0));
      committed[seat] = Math.max(committed[seat] || 0, to);
      totalCommitted[seat] += add;
      if (to > currentBet) {
        currentBet = to;
        lastAggressor = seat;
      }
      actedThisStreet.add(seat);
      allInSet.add(seat); // persists across streets (committed resets, this doesn't)
      lastActor = seat;
    }
  }

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
        ? b
          ? b.bb
          : button // preflop: walk from BB so UTG is first
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
  };
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

// Rake-adjusted winnings: winners bear the rake proportionally to their gross.
export function settleResult(totalCommitted, winners, rake) {
  const { winnings, unresolved } = distributePots(totalCommitted, winners);
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
  return { winnings: out, unresolved };
}

// Settle stacks after a hand: newStack = stack − committed + winnings. Seats
// with a null stack (untracked) are left untouched.
export function settleStacks(seats, state, winners, rake) {
  const { winnings } = settleResult(state.totalCommitted, winners, rake);
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
