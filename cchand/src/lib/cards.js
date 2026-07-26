import { SUITS } from "../constants.js";

export const suitMeta = (k) => SUITS.find((x) => x.key === k);
export const cardId = (c) => (c ? c.rank + c.suit : null);
export const cardStr = (c) => (c ? c.rank + c.suit : "··");

// ---- hand geometry ----
// A hand's card array is `boards` five-card boards followed by the hero's hole
// cards: board k at [5k..5k+4], hero at [5*boards..]. NLHE = 1 board / 2 hole
// (the legacy len-7 layout); PLO = 4 hole; a double-board bomb pot = 2 boards.
export const GEO_NLHE = { boards: 1, hole: 2 };
export const geoOf = (h) => ({ boards: h?.boards || 1, hole: h?.hole || 2 });
export const holeStartOf = (geo) => 5 * (geo?.boards || 1);
export const totalOf = (geo) => 5 * (geo?.boards || 1) + (geo?.hole || 2);
export const emptyHand = (geo) => Array(totalOf(geo)).fill(null);

// Board-card indices for a street across all boards (flop first board, then
// second): flop = 0,1,2[,5,6,7]; turn = 3[,8]; river = 4[,9].
export function streetIndices(street, geo) {
  const boards = geo?.boards || 1;
  const per = { flop: [0, 1, 2], turn: [3], river: [4] }[street] || [];
  const out = [];
  for (let b = 0; b < boards; b++) per.forEach((i) => out.push(5 * b + i));
  return out;
}

export function streetOf(index, geo) {
  const hs = holeStartOf(geo);
  if (index >= hs) return "Hero";
  const i = index % 5;
  return i < 3 ? "Flop" : i === 3 ? "Turn" : "River";
}

export const communityComplete = (cards, street, geo) =>
  streetIndices(street, geo).every((i) => !!cards[i]);

export const firstCommunityIndex = (street, cards, geo) => {
  const idxs = streetIndices(street, geo);
  return idxs.find((i) => !cards[i]) ?? idxs[0] ?? 0;
};

export const firstEmpty = (cards) => {
  const i = cards.findIndex((c) => c === null);
  return i === -1 ? null : i;
};

// One board's display string: "AhKd2c 7s Jh".
const oneBoardStr = (c, b = 0) =>
  [c.slice(5 * b, 5 * b + 3), [c[5 * b + 3]], [c[5 * b + 4]]]
    .map((g) => g.map(cardStr).join(""))
    .join(" ");

export const boardStr = (c, geo) => {
  const boards = geo?.boards || 1;
  return Array.from({ length: boards }, (_, b) => oneBoardStr(c, b)).join(" / ");
};

export const holeStr = (c, geo) => {
  const hs = holeStartOf(geo);
  return c.slice(hs, hs + (geo?.hole || 2)).map(cardStr).join("");
};

export const hhmm = (ts) =>
  new Date(ts).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });

export const sameTarget = (a, t) =>
  a && t && a.type === t.type &&
  (t.type === "board" ? a.index === t.index : a.r === t.r && a.c === t.c);
