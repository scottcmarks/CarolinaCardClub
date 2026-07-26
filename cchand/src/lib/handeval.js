// Pure hand evaluator — determines the winner(s) at showdown from the board +
// each shown hand, retiring the winner-tap scaffolding (the tap survives only
// as the override for mucked / unknown hands).
//
// Hold'em: best 5 of any 7. Omaha (PLO): EXACTLY 2 of the 4 hole cards +
// exactly 3 board cards — a board flush isn't yours without two of that suit
// in hand. Double-board bomb pots score each board separately (half pot each).
//
// Cards are { rank, suit } with rank in A K Q J T 9..2 and suit in s h d c.
// Suits never break ties — equal keys ⇒ a chop.

const VAL = { A: 14, K: 13, Q: 12, J: 11, T: 10, 9: 9, 8: 8, 7: 7, 6: 6, 5: 5, 4: 4, 3: 3, 2: 2 };
const CAT = [
  "High card", "Pair", "Two pair", "Three of a kind", "Straight",
  "Flush", "Full house", "Four of a kind", "Straight flush",
];

// Score exactly 5 cards → a comparable key [category, ...tiebreakers].
function eval5(cs) {
  const vals = cs.map((c) => VAL[c.rank]).sort((a, b) => b - a);
  const flush = cs.every((c) => c.suit === cs[0].suit);
  const uniq = [...new Set(vals)];
  let sHigh = 0; // straight high card (0 = not a straight)
  if (uniq.length === 5) {
    if (uniq[0] - uniq[4] === 4) sHigh = uniq[0];
    else if (uniq[0] === 14 && uniq[1] === 5) sHigh = 5; // wheel A-2-3-4-5 = 5-high
  }
  const cnt = {};
  vals.forEach((v) => (cnt[v] = (cnt[v] || 0) + 1));
  // groups sorted by count desc, then rank desc → tiebreak ranks in that order
  const groups = Object.keys(cnt)
    .map((r) => ({ r: +r, c: cnt[r] }))
    .sort((a, b) => b.c - a.c || b.r - a.r);
  const shape = groups.map((g) => g.c).join("");
  const tb = groups.map((g) => g.r);

  if (sHigh && flush) return [8, sHigh];
  if (shape === "41") return [7, ...tb]; // quads, kicker
  if (shape === "32") return [6, ...tb]; // trips over pair
  if (flush) return [5, ...vals]; // five ranks high→low
  if (sHigh) return [4, sHigh];
  if (shape === "311") return [3, ...tb]; // trips + 2 kickers
  if (shape === "221") return [2, ...tb]; // two pair + kicker
  if (shape === "2111") return [1, ...tb]; // pair + 3 kickers
  return [0, ...vals]; // high card
}

export function cmpKey(a, b) {
  const n = Math.max(a.length, b.length);
  for (let i = 0; i < n; i++) {
    const x = a[i] ?? 0;
    const y = b[i] ?? 0;
    if (x !== y) return x > y ? 1 : -1;
  }
  return 0;
}

function combos5(a) {
  const r = [];
  const n = a.length;
  for (let i = 0; i < n; i++)
    for (let j = i + 1; j < n; j++)
      for (let k = j + 1; k < n; k++)
        for (let l = k + 1; l < n; l++)
          for (let m = l + 1; m < n; m++) r.push([a[i], a[j], a[k], a[l], a[m]]);
  return r;
}

// Best 5-card key from 5–7 cards (null if fewer than 5 usable cards).
export function bestKey(cards) {
  const cs = cards.filter(Boolean);
  if (cs.length < 5) return null;
  let best = null;
  for (const combo of combos5(cs)) {
    const k = eval5(combo);
    if (!best || cmpKey(k, best) > 0) best = k;
  }
  return best;
}

export const handName = (key) => (key ? CAT[key[0]] : "");

const pairs = (a) => {
  const r = [];
  for (let i = 0; i < a.length; i++) for (let j = i + 1; j < a.length; j++) r.push([a[i], a[j]]);
  return r;
};
const triples = (a) => {
  const r = [];
  for (let i = 0; i < a.length; i++)
    for (let j = i + 1; j < a.length; j++)
      for (let k = j + 1; k < a.length; k++) r.push([a[i], a[j], a[k]]);
  return r;
};

// Best Omaha key: exactly 2 of the (4) hole cards + exactly 3 of the board.
// Needs a full hand and a full board; returns null otherwise.
export function bestKeyOmaha(hole, board) {
  const h = (hole || []).filter(Boolean);
  const b = (board || []).filter(Boolean);
  if (h.length < 4 || b.length < 5) return null;
  let best = null;
  for (const hp of pairs(h))
    for (const bt of triples(b)) {
      const k = eval5([...hp, ...bt]);
      if (!best || cmpKey(k, best) > 0) best = k;
    }
  return best;
}

// Determine one board's showdown winner(s). Only fully-shown hands compete
// (Hold'em: both cards; Omaha: all four — you show your whole hand to win).
//   contenders : [{ seat, cards:[…] }]  (cards may be null/partial = unshown)
//   board      : that board's 5 community cards
//   omaha      : use the exactly-2-from-hand rule
// Returns { winners:[seat…], names:{seat:name}, best } or null if nobody showed.
export function showdownWinners(contenders, board, omaha = false) {
  const need = omaha ? 4 : 2;
  const scored = [];
  for (const c of contenders) {
    const cs = (c.cards || []).filter(Boolean);
    if (cs.length < need) continue; // unshown / partial
    const key = omaha ? bestKeyOmaha(cs, board) : bestKey([...cs, ...board]);
    if (key) scored.push({ seat: c.seat, key });
  }
  if (!scored.length) return null;
  let top = scored[0].key;
  for (const s of scored) if (cmpKey(s.key, top) > 0) top = s.key;
  const winners = scored.filter((s) => cmpKey(s.key, top) === 0).map((s) => s.seat);
  const names = {};
  scored.forEach((s) => (names[s.seat] = handName(s.key)));
  return { winners, names, best: handName(top) };
}

// Multi-board showdown (double-board bomb pot): score each board separately.
//   boards : [board5, board5, …]
// Returns { perBoard: [{winners,best}|null …], names, any } — `names` labels a
// seat "Flush / Two pair" across boards; `any` is true if any board resolved.
export function showdownWinnersMulti(contenders, boards, omaha = false) {
  const perBoard = boards.map((b) => showdownWinners(contenders, b, omaha));
  const names = {};
  contenders.forEach((c) => {
    const parts = perBoard.map((r) => (r && r.names[c.seat]) || null);
    if (parts.some(Boolean)) names[c.seat] = parts.map((p) => p || "—").join(" / ");
  });
  return { perBoard, names, any: perBoard.some(Boolean) };
}
