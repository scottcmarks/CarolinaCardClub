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
    }
  }

  const pot = occ.reduce((s, seat) => s + (totalCommitted[seat] || 0), 0);

  const needsAct = (seat) =>
    inHand.has(seat) &&
    (!actedThisStreet.has(seat) || (committed[seat] || 0) < currentBet);

  const anyNeeds = occ.some(needsAct);
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

// Chips a seat must put in to call the current bet.
export const toCall = (state, seat) =>
  Math.max(0, state.currentBet - (state.committed[seat] || 0));

// Suggested minimum legal raise-to (not enforced — a hint for the pad).
export const minRaiseTo = (state, bbAmt) =>
  state.currentBet > 0 ? state.currentBet * 2 : bbAmt;
