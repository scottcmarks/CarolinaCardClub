import { boardStr, holeStr, hhmm, cardStr } from "./cards.js";
import { actionsSummary } from "./betting.js";

const ctxOf = (h) =>
  [h.location, h.table && "T" + h.table, h.seat && "S" + h.seat].filter(Boolean).join(" ");

const revealsText = (h) =>
  h.reveals
    .map((r) => (r.seat ? "S" + r.seat + ":" : "") + r.cards.map(cardStr).join(""))
    .join("  ");

const moneyText = (h) =>
  h.pot != null ? `pot $${h.pot}${h.rake != null ? " rake $" + h.rake : ""}` : "";

// Human-readable session dump (newest hand last, matching play order).
export function toText(log) {
  return log
    .slice()
    .reverse()
    .map((h, i) => {
      const ctx = ctxOf(h);
      const rv = revealsText(h);
      const money = moneyText(h);
      const acts = actionsSummary(h.actions);
      const heroShown = !holeStr(h.cards).includes("·")
        ? "  hero " + holeStr(h.cards) + (h.heroRevealed ? " (shown)" : " (mucked)")
        : "";
      return (
        `#${i + 1} ${hhmm(h.ts)}${ctx ? "  " + ctx : ""}  |  ${boardStr(h.cards)}` +
        heroShown +
        (rv ? "  |  " + rv : "") +
        (money ? "  |  " + money : "") +
        (acts ? "\n     " + acts : "")
      );
    })
    .join("\n");
}

// CSV for spreadsheets / trackers. One row per hand; reveals collapsed to one column.
export function toCSV(log) {
  const head = [
    "time", "location", "table", "seat", "hero_name",
    "flop", "turn", "river", "hero", "hero_shown",
    "pot", "rake", "reveals", "actions",
  ];
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
      const heroShown = hero ? (h.heroRevealed ? "yes" : "no") : "";
      const reveals = h.reveals
        .map((r) => (r.seat ? "S" + r.seat + ":" : "") + r.cards.map(cardStr).join(""))
        .join("; ");
      return [
        new Date(h.ts).toISOString(),
        h.location,
        h.table,
        h.seat,
        h.heroName || "",
        flop,
        turn,
        river,
        hero,
        heroShown,
        h.pot ?? "",
        h.rake ?? "",
        reveals,
        actionsSummary(h.actions),
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
