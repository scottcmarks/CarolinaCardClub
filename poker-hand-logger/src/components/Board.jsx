import { Fragment } from "react";
import { ChevronRight } from "lucide-react";
import { STREETS, HOLE_START, theme } from "../constants.js";
import { sameTarget } from "../lib/cards.js";
import Slot from "./Slot.jsx";

export default function Board({ cards, active, onSelect }) {
  const groups = [];
  let idx = 0;
  for (const st of STREETS) {
    const slots = [];
    for (let k = 0; k < st.n; k++) {
      const i = idx;
      const target = { type: "board", index: i };
      slots.push(
        <Slot
          key={i}
          card={cards[i]}
          isActive={sameTarget(active, target)}
          onSelect={() => onSelect(target)}
          hole={i >= HOLE_START}
        />
      );
      idx++;
    }
    groups.push(
      <Fragment key={st.name}>
        {st.terminal && (
          <div className="self-center" style={{ color: "rgba(255,255,255,0.25)" }}>
            <ChevronRight size={15} />
          </div>
        )}
        <div className="flex flex-col items-center gap-1">
          <div className="flex gap-1">{slots}</div>
          <span
            className="uppercase"
            style={{
              fontSize: 9,
              letterSpacing: "0.12em",
              color: st.terminal ? "rgba(201,162,39,0.75)" : "rgba(255,255,255,0.45)",
            }}
          >
            {st.name}
          </span>
        </div>
      </Fragment>
    );
  }
  return <div className="flex items-start justify-center gap-1.5">{groups}</div>;
}
