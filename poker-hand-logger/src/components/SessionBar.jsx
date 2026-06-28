import { useState } from "react";
import { MapPin, Pencil, List } from "lucide-react";
import { theme } from "../constants.js";

const inputStyle = {
  background: "rgba(255,255,255,0.08)",
  color: theme.textLight,
  fontSize: 13,
  border: "1px solid rgba(255,255,255,0.1)",
};

export default function SessionBar({ session, updateSession, logCount, onOpenHistory }) {
  const [editing, setEditing] = useState(false);
  const summary = [
    session.location || "Set venue",
    "T" + (session.table || "–"),
    "S" + (session.seat || "–"),
  ].join("  ·  ");

  return (
    <>
      <div className="flex items-center gap-2 mb-2">
        <button
          onClick={() => setEditing((v) => !v)}
          className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg flex-1 min-w-0"
          style={{ background: "rgba(255,255,255,0.06)", color: theme.textLight, fontSize: 12.5 }}
        >
          <MapPin size={13} color={theme.gold} />
          <span className="truncate">{summary}</span>
          <Pencil size={11} color="rgba(255,255,255,0.5)" />
        </button>
        <button
          onClick={onOpenHistory}
          className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg shrink-0"
          style={{ background: "rgba(255,255,255,0.06)", color: theme.textLight, fontSize: 12 }}
        >
          <List size={13} /> {logCount}
        </button>
      </div>

      {editing && (
        <div className="grid grid-cols-2 gap-2 mb-3 p-2.5 rounded-xl" style={{ background: "rgba(0,0,0,0.2)" }}>
          <input
            value={session.location}
            onChange={(e) => updateSession({ location: e.target.value })}
            placeholder="Venue"
            className="col-span-2 px-2.5 py-2 rounded-lg outline-none"
            style={inputStyle}
          />
          <input
            value={session.table}
            inputMode="numeric"
            onChange={(e) => updateSession({ table: e.target.value.replace(/\D/g, "").slice(0, 3) })}
            placeholder="Table #"
            className="px-2.5 py-2 rounded-lg outline-none"
            style={inputStyle}
          />
          <input
            value={session.seat}
            inputMode="numeric"
            onChange={(e) => updateSession({ seat: e.target.value.replace(/\D/g, "").slice(0, 2) })}
            placeholder="Seat #"
            className="px-2.5 py-2 rounded-lg outline-none"
            style={inputStyle}
          />
        </div>
      )}
    </>
  );
}
