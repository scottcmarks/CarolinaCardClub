import { X, Plus } from "lucide-react";
import { sameTarget } from "../lib/cards.js";
import Slot from "./Slot.jsx";

export default function Reveals({ reveals, active, onSelect, onAdd, onRemove, onSeat }) {
  return (
    <div className="mt-3">
      <div className="flex items-center gap-2 overflow-x-auto pb-1 no-scrollbar">
        {reveals.map((rv, r) => (
          <div
            key={r}
            className="flex flex-col items-center gap-1 shrink-0 px-2 py-1.5 rounded-lg"
            style={{ background: "rgba(0,0,0,0.18)" }}
          >
            <div className="flex gap-1">
              {[0, 1].map((c) => {
                const target = { type: "reveal", r, c };
                return (
                  <Slot
                    key={c}
                    card={rv.cards[c]}
                    isActive={sameTarget(active, target)}
                    onSelect={() => onSelect(target)}
                    w={30}
                    h={42}
                  />
                );
              })}
            </div>
            <div className="flex items-center gap-1">
              <span style={{ fontSize: 9, color: "rgba(255,255,255,0.5)" }}>S</span>
              <input
                value={rv.seat}
                inputMode="numeric"
                placeholder="–"
                onChange={(e) => onSeat(r, e.target.value)}
                className="text-center outline-none rounded"
                style={{ width: 26, fontSize: 11, color: "#F6F3EA", background: "rgba(255,255,255,0.08)" }}
              />
              <button onClick={() => onRemove(r)} style={{ color: "rgba(255,255,255,0.4)" }}>
                <X size={12} />
              </button>
            </div>
          </div>
        ))}
        <button
          onClick={onAdd}
          className="flex flex-col items-center justify-center gap-1 shrink-0 rounded-lg"
          style={{
            width: 58,
            height: 64,
            border: "1px dashed rgba(255,255,255,0.25)",
            color: "rgba(255,255,255,0.6)",
            fontSize: 10,
          }}
        >
          <Plus size={16} /> Reveal
        </button>
      </div>
    </div>
  );
}
