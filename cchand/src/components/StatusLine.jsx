import { theme } from "../constants.js";
import { toCall as toCallFn } from "../lib/betting.js";

const dim = { color: "rgba(255,255,255,0.55)", fontSize: 12.5 };
const cap = (s) => (s ? s[0].toUpperCase() + s.slice(1) : s);

export default function StatusLine({
  flash,
  pendingRank,
  active,
  mode,
  phase,
  dealingStreet,
  bet,
  seats,
  heroSeat,
  heroName,
  holeStart = 5,
  editing,
}) {
  let content;
  const nameOf = (n) =>
    n === heroSeat ? heroName || "You" : (seats[n - 1] && seats[n - 1].name) || `Seat ${n}`;

  if (flash) {
    content = <span style={{ color: theme.gold, fontSize: 12.5, fontWeight: 600 }}>{flash}</span>;
  } else if (pendingRank) {
    content = (
      <span style={dim}>
        Pick a suit for <b style={{ color: theme.textLight }}>{pendingRank}</b>
      </span>
    );
  } else if (mode === "cards" && dealingStreet) {
    content = (
      <span style={dim}>
        Deal the <b style={{ color: theme.gold }}>{cap(dealingStreet)}</b>
      </span>
    );
  } else if (mode === "cards" && phase === "showdown") {
    content = <span style={dim}>Showdown — tap a seat to record a shown hand, or end the hand</span>;
  } else if (mode === "cards" && active.type === "board" && active.index >= holeStart) {
    content = <span style={dim}>Your cards</span>;
  } else if (mode === "cards" && active.type === "reveal") {
    content = <span style={dim}>Shown hand · card {active.c + 1}</span>;
  } else if (mode === "betting" && bet.actor != null) {
    const owed = toCallFn(bet, bet.actor);
    content = (
      <span style={dim}>
        <b style={{ color: theme.gold }}>{cap(phase)}</b> · {nameOf(bet.actor)} to act
        {owed > 0 ? ` · to call $${owed}` : " · can check"}
      </span>
    );
  } else if (mode === "betting") {
    content = <span style={dim}>{cap(phase)} betting</span>;
  } else {
    content = <span style={dim}>{editing ? "Editing hand" : "—"}</span>;
  }
  return <div className="h-6 flex items-center justify-center mt-2 mb-1">{content}</div>;
}
