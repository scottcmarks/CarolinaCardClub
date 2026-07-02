import { Undo2, Trash2, ChevronRight, X } from "lucide-react";
import { theme } from "../constants.js";

const ghost = { background: "rgba(255,255,255,0.08)" };

export default function Actions({
  pendingRank, canUndo, anyEntered, editing,
  onCancelPending, onUndo, onClear, onEnd,
}) {
  if (pendingRank) {
    return (
      <div className="flex gap-2 mt-3">
        <button
          onClick={onCancelPending}
          className="flex-1 h-11 rounded-xl flex items-center justify-center gap-2"
          style={{ ...ghost, color: theme.textLight, fontSize: 14 }}
        >
          <X size={16} /> Cancel
        </button>
      </div>
    );
  }
  return (
    <div className="flex gap-2 mt-3">
      <button
        onClick={onUndo}
        disabled={!canUndo}
        className="h-11 px-4 rounded-xl flex items-center justify-center"
        style={{ ...ghost, color: canUndo ? theme.textLight : "rgba(255,255,255,0.3)" }}
      >
        <Undo2 size={16} />
      </button>
      <button
        onClick={onClear}
        disabled={!anyEntered}
        className="h-11 px-4 rounded-xl flex items-center justify-center"
        style={{ ...ghost, color: anyEntered ? theme.textLight : "rgba(255,255,255,0.3)" }}
      >
        <Trash2 size={16} />
      </button>
      <button
        onClick={onEnd}
        disabled={!anyEntered}
        className="flex-1 h-11 rounded-xl flex items-center justify-center gap-2 font-semibold"
        style={{
          background: anyEntered ? theme.gold : "rgba(201,162,39,0.2)",
          color: anyEntered ? theme.ink : "rgba(255,255,255,0.35)",
          fontSize: 14,
        }}
      >
        {editing ? "Update hand" : "End hand"} <ChevronRight size={16} />
      </button>
    </div>
  );
}
