import { SUITS, STREETS } from "../constants.js";

export const suitMeta = (k) => SUITS.find((x) => x.key === k);
export const cardId = (c) => (c ? c.rank + c.suit : null);
export const cardStr = (c) => (c ? c.rank + c.suit : "··");

export const firstEmpty = (cards) => {
  const i = cards.findIndex((c) => c === null);
  return i === -1 ? null : i;
};

export function streetOf(index) {
  let i = index;
  for (const st of STREETS) {
    if (i < st.n) return st.name;
    i -= st.n;
  }
  return "";
}

export const boardStr = (c) =>
  [c.slice(0, 3), [c[3]], [c[4]]].map((g) => g.map(cardStr).join("")).join(" ");

export const holeStr = (c) => c.slice(5, 7).map(cardStr).join("");

export const hhmm = (ts) =>
  new Date(ts).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });

export const sameTarget = (a, t) =>
  a && t && a.type === t.type &&
  (t.type === "board" ? a.index === t.index : a.r === t.r && a.c === t.c);
