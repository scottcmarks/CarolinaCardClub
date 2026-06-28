import { HOLE_START, theme } from "../constants.js";
import { streetOf } from "../lib/cards.js";

const dim = { color: "rgba(255,255,255,0.55)", fontSize: 12.5 };

export default function StatusLine({ flash, pendingRank, active, editing }) {
  let content;
  if (flash) {
    content = <span style={{ color: theme.gold, fontSize: 12.5, fontWeight: 600 }}>{flash}</span>;
  } else if (pendingRank) {
    content = (
      <span style={dim}>
        Pick a suit for <b style={{ color: theme.textLight }}>{pendingRank}</b>
      </span>
    );
  } else if (active.type === "reveal") {
    content = <span style={dim}>Revealed hand · card {active.c + 1}</span>;
  } else if (active.index >= HOLE_START) {
    content = (
      <span style={dim}>
        {editing ? (
          "Hero cards"
        ) : (
          <>
            Hero cards — fills both to <b style={{ color: theme.gold }}>end the hand</b>
          </>
        )}
      </span>
    );
  } else {
    content = (
      <span style={dim}>
        Entering <b style={{ color: theme.gold }}>{streetOf(active.index)}</b>
      </span>
    );
  }
  return <div className="h-6 flex items-center justify-center mt-2 mb-1">{content}</div>;
}
