import { Copy, X, Trash2, FileText } from "lucide-react";
import { theme } from "../constants.js";
import { hhmm, holeStr } from "../lib/cards.js";
import { toText, toCSV, download } from "../lib/export.js";
import Chip from "./Chip.jsx";

export default function HistoryPanel({ log, editingId, onClose, onEdit, onDelete }) {
  const copyAll = () => {
    if (log.length && navigator.clipboard) navigator.clipboard.writeText(toText(log));
  };
  const exportCsv = () => {
    if (log.length) download("poker-hands.csv", toCSV(log), "text/csv");
  };

  return (
    <div
      className="fixed inset-0 z-50 flex justify-center"
      style={{ background: "rgba(0,0,0,0.55)" }}
      onClick={onClose}
    >
      <div
        className="w-full max-w-sm flex flex-col"
        style={{ background: theme.panel, borderTop: "1px solid rgba(255,255,255,0.08)" }}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between px-4 py-3" style={{ borderBottom: "1px solid rgba(255,255,255,0.08)" }}>
          <span style={{ color: theme.textLight, fontSize: 15, fontWeight: 700 }}>Hands · {log.length}</span>
          <div className="flex items-center gap-2">
            <button onClick={copyAll} disabled={!log.length} className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg"
              style={{ background: "rgba(255,255,255,0.08)", color: log.length ? theme.textLight : "rgba(255,255,255,0.3)", fontSize: 12.5 }}>
              <Copy size={13} /> Copy
            </button>
            <button onClick={exportCsv} disabled={!log.length} className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg"
              style={{ background: "rgba(255,255,255,0.08)", color: log.length ? theme.textLight : "rgba(255,255,255,0.3)", fontSize: 12.5 }}>
              <FileText size={13} /> CSV
            </button>
            <button onClick={onClose} className="p-1.5 rounded-lg" style={{ background: "rgba(255,255,255,0.08)", color: theme.textLight }}>
              <X size={16} />
            </button>
          </div>
        </div>

        <div className="flex-1 overflow-y-auto px-3 py-2">
          {log.length === 0 ? (
            <div className="text-center py-10" style={{ color: "rgba(255,255,255,0.4)", fontSize: 13 }}>
              No hands yet. Log one to see it here.
            </div>
          ) : (
            log.map((h) => (
              <div
                key={h.id}
                onClick={() => onEdit(h)}
                className="mb-2 p-3 rounded-xl cursor-pointer"
                style={{
                  background: h.id === editingId ? "rgba(201,162,39,0.15)" : "rgba(255,255,255,0.04)",
                  border: h.id === editingId ? "1px solid rgba(201,162,39,0.5)" : "1px solid rgba(255,255,255,0.06)",
                }}
              >
                <div className="flex items-center justify-between mb-1.5">
                  <span style={{ color: theme.textLight, fontSize: 12.5 }}>
                    <b>{hhmm(h.ts)}</b>
                    <span style={{ color: "rgba(255,255,255,0.5)" }}>
                      {[h.location, h.table && "T" + h.table, h.seat && "S" + h.seat].filter(Boolean).map((x) => "  " + x)}
                    </span>
                  </span>
                  <button onClick={(e) => { e.stopPropagation(); onDelete(h.id); }} style={{ color: "rgba(255,255,255,0.35)" }}>
                    <Trash2 size={14} />
                  </button>
                </div>
                <div className="flex items-center flex-wrap gap-y-1">
                  {h.cards.slice(0, 3).map((c, i) => <Chip key={"f" + i} c={c} />)}
                  <span style={{ width: 4 }} />
                  <Chip c={h.cards[3]} />
                  <span style={{ width: 4 }} />
                  <Chip c={h.cards[4]} />
                  {!holeStr(h.cards).includes("·") && (
                    <>
                      <span style={{ color: "rgba(201,162,39,0.8)", fontSize: 10, margin: "0 4px" }}>HERO</span>
                      <Chip c={h.cards[5]} />
                      <Chip c={h.cards[6]} />
                    </>
                  )}
                </div>
                {h.reveals.length > 0 && (
                  <div className="flex items-center flex-wrap gap-y-1 mt-1.5">
                    {h.reveals.map((rv, ri) => (
                      <span key={ri} className="flex items-center mr-2">
                        <span style={{ color: "rgba(255,255,255,0.5)", fontSize: 10, marginRight: 3 }}>{rv.seat ? "S" + rv.seat : "?"}</span>
                        {rv.cards.map((c, ci) => <Chip key={ci} c={c} />)}
                      </span>
                    ))}
                  </div>
                )}
                <div style={{ color: "rgba(201,162,39,0.7)", fontSize: 10.5, marginTop: 6 }}>Tap to edit</div>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}
