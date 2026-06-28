import { boardStr, holeStr, hhmm, cardStr } from "./cards.js";

const ctxOf = (h) =>
  [h.location, h.table && "T" + h.table, h.seat && "S" + h.seat].filter(Boolean).join(" ");

const revealsText = (h) =>
  h.reveals
    .map((r) => (r.seat ? "S" + r.seat + ":" : "") + r.cards.map(cardStr).join(""))
    .join("  ");

// Human-readable session dump (newest hand last, matching play order).
export function toText(log) {
  return log
    .slice()
    .reverse()
    .map((h, i) => {
      const ctx = ctxOf(h);
      const rv = revealsText(h);
      return (
        `#${i + 1} ${hhmm(h.ts)}${ctx ? "  " + ctx : ""}  |  ${boardStr(h.cards)}` +
        (holeStr(h.cards).includes("·") ? "" : "  hero " + holeStr(h.cards)) +
        (rv ? "  |  " + rv : "")
      );
    })
    .join("\n");
}

// CSV for spreadsheets / trackers. One row per hand; reveals collapsed to one column.
export function toCSV(log) {
  const head = ["time", "location", "table", "seat", "flop", "turn", "river", "hero", "reveals"];
  const esc = (v) => {
    const s = String(v ?? "");
    return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
  };
  const rows = log
    .slice()
    .reverse()
    .map((h) => {
      const flop = h.cards.slice(0, 3).map(cardStr).join("");
      const turn = cardStr(h.cards[3]);
      const river = cardStr(h.cards[4]);
      const hero = holeStr(h.cards).includes("·") ? "" : holeStr(h.cards);
      const reveals = h.reveals
        .map((r) => (r.seat ? "S" + r.seat + ":" : "") + r.cards.map(cardStr).join(""))
        .join("; ");
      return [
        new Date(h.ts).toISOString(),
        h.location,
        h.table,
        h.seat,
        flop,
        turn,
        river,
        hero,
        reveals,
      ].map(esc).join(",");
    });
  return [head.join(","), ...rows].join("\n");
}

export function download(filename, text, mime = "text/plain") {
  const blob = new Blob([text], { type: mime });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}
