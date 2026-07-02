import { MapPin, Settings, List } from "lucide-react";
import { theme } from "../constants.js";

export default function SessionBar({ session, logCount, onOpenHistory, onOpenSetup }) {
  const summary = [
    session.location || "Set venue",
    "T" + (session.table || "–"),
    session.heroName || "You",
    "S" + (session.seat || "–"),
  ].join("  ·  ");

  return (
    <div className="flex items-center gap-2 mb-2">
      <button
        onClick={onOpenSetup}
        className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg flex-1 min-w-0"
        style={{ background: "rgba(255,255,255,0.06)", color: theme.textLight, fontSize: 12.5 }}
      >
        <MapPin size={13} color={theme.gold} />
        <span className="truncate">{summary}</span>
        <Settings size={12} color="rgba(255,255,255,0.5)" />
      </button>
      <button
        onClick={onOpenHistory}
        className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg shrink-0"
        style={{ background: "rgba(255,255,255,0.06)", color: theme.textLight, fontSize: 12 }}
      >
        <List size={13} /> {logCount}
      </button>
    </div>
  );
}
