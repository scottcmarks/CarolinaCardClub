import { useState } from "react";
import { SEAT_COUNT, defaultSeats, theme } from "../constants.js";
import { rakeSummary } from "../lib/rake.js";
import RakeEditor from "./RakeEditor.jsx";

const field = {
  background: "rgba(255,255,255,0.08)",
  color: theme.textLight,
  fontSize: 15,
  border: "1px solid rgba(255,255,255,0.12)",
};

// A small two-option segmented control.
function Seg({ label, value, options, onChange }) {
  return (
    <label style={{ color: "rgba(255,255,255,0.6)", fontSize: 12 }}>
      {label}
      <div
        className="mt-1 flex rounded-lg overflow-hidden"
        style={{ border: "1px solid rgba(255,255,255,0.12)" }}
      >
        {options.map((o) => {
          const on = o.value === value;
          return (
            <button
              key={o.value}
              onClick={() => onChange(o.value)}
              className="flex-1 py-2"
              style={{
                fontSize: 13,
                fontWeight: on ? 700 : 400,
                background: on ? theme.gold : "rgba(255,255,255,0.04)",
                color: on ? theme.ink : "rgba(255,255,255,0.6)",
              }}
            >
              {o.label}
            </button>
          );
        })}
      </div>
    </label>
  );
}

// Startup / re-openable setup: venue, table, hero name + seat, which seats are
// occupied, the button, and the rake profile.
export default function Onboarding({ session, rakes, onDone, onClose, onUpsertRake, onDeleteRake }) {
  const [editingRake, setEditingRake] = useState(null); // null | "new" | profile
  const [venue, setVenue] = useState(session.location || "");
  const [table, setTable] = useState(session.table || "");
  const [heroName, setHeroName] = useState(session.heroName || "Scott");
  const [heroSeat, setHeroSeat] = useState(parseInt(session.seat, 10) || 2);
  const [button, setButton] = useState(session.button || 1);
  const [dealt, setDealt] = useState(session.dealt === "self" ? "self" : "dealer");
  const [tableShape, setTableShape] = useState(session.tableShape === "rect" ? "rect" : "oval");
  const [rakeProfileId, setRakeProfileId] = useState(session.rakeProfileId || rakes[0]?.id);
  const [seats, setSeats] = useState(
    session.seats && session.seats.length ? session.seats.map((s) => ({ ...s })) : defaultSeats()
  );

  const toggleSeat = (i) => {
    if (i + 1 === heroSeat) return; // hero's seat can't be vacated
    setSeats((p) => p.map((s, j) => (j === i ? { ...s, occupied: !s.occupied } : s)));
  };
  const renameSeat = (i, name) =>
    setSeats((p) => p.map((s, j) => (j === i ? { ...s, name } : s)));
  const restack = (i, v) =>
    setSeats((p) =>
      p.map((s, j) =>
        j === i ? { ...s, stack: v === "" ? null : Math.max(0, parseInt(v, 10) || 0) } : s
      )
    );

  const submit = () => {
    const hn = heroName.trim() || "Hero";
    // hero's seat is always occupied and carries the hero's name
    const outSeats = seats.map((s, i) =>
      i + 1 === heroSeat ? { ...s, occupied: true, name: hn } : s
    );
    onDone({
      location: venue.trim(),
      table: String(table).replace(/\D/g, "").slice(0, 3),
      heroName: hn,
      seat: String(heroSeat),
      button,
      dealt,
      tableShape,
      rakeProfileId,
      seats: outSeats,
    });
  };

  const profile = rakes.find((r) => r.id === rakeProfileId);

  return (
    <div className="fixed inset-0 z-[70] flex justify-center" style={{ background: "rgba(0,0,0,0.7)" }}>
      <div
        className="w-full max-w-sm flex flex-col overflow-y-auto"
        style={{ background: theme.panel }}
      >
        <div
          className="px-4 py-3 flex items-center justify-between"
          style={{ borderBottom: "1px solid rgba(255,255,255,0.08)" }}
        >
          <span style={{ color: theme.textLight, fontSize: 16, fontWeight: 700 }}>Table setup</span>
          {onClose && (
            <button onClick={onClose} style={{ color: "rgba(255,255,255,0.6)", fontSize: 13 }}>
              Close
            </button>
          )}
        </div>

        <div className="px-4 py-3 flex flex-col gap-3">
          <label style={{ color: "rgba(255,255,255,0.6)", fontSize: 12 }}>
            Venue
            <input
              value={venue}
              onChange={(e) => setVenue(e.target.value)}
              placeholder="Danville"
              className="w-full mt-1 px-3 py-2 rounded-lg outline-none"
              style={field}
            />
          </label>

          <div className="grid grid-cols-2 gap-3">
            <label style={{ color: "rgba(255,255,255,0.6)", fontSize: 12 }}>
              Table #
              <input
                value={table}
                inputMode="numeric"
                onChange={(e) => setTable(e.target.value)}
                placeholder="1"
                className="w-full mt-1 px-3 py-2 rounded-lg outline-none"
                style={field}
              />
            </label>
            <label style={{ color: "rgba(255,255,255,0.6)", fontSize: 12 }}>
              Your name
              <input
                value={heroName}
                onChange={(e) => setHeroName(e.target.value)}
                className="w-full mt-1 px-3 py-2 rounded-lg outline-none"
                style={field}
              />
            </label>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <label style={{ color: "rgba(255,255,255,0.6)", fontSize: 12 }}>
              Your seat
              <select
                value={heroSeat}
                onChange={(e) => setHeroSeat(parseInt(e.target.value, 10))}
                className="w-full mt-1 px-3 py-2 rounded-lg outline-none"
                style={field}
              >
                {Array.from({ length: SEAT_COUNT }, (_, i) => i + 1).map((n) => (
                  <option key={n} value={n}>
                    Seat {n}
                  </option>
                ))}
              </select>
            </label>
            <label style={{ color: "rgba(255,255,255,0.6)", fontSize: 12 }}>
              Button on seat
              <select
                value={button}
                onChange={(e) => setButton(parseInt(e.target.value, 10))}
                className="w-full mt-1 px-3 py-2 rounded-lg outline-none"
                style={field}
              >
                {Array.from({ length: SEAT_COUNT }, (_, i) => i + 1).map((n) => (
                  <option key={n} value={n}>
                    Seat {n}
                  </option>
                ))}
              </select>
            </label>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <Seg
              label="Dealing"
              value={dealt}
              onChange={setDealt}
              options={[
                { value: "dealer", label: "Dealer" },
                { value: "self", label: "Self-dealt" },
              ]}
            />
            <Seg
              label="Table shape"
              value={tableShape}
              onChange={setTableShape}
              options={[
                { value: "oval", label: "Oval" },
                { value: "rect", label: "Rect" },
              ]}
            />
          </div>

          <div style={{ color: "rgba(255,255,255,0.6)", fontSize: 12 }}>
            <div className="flex items-center justify-between">
              <span>Stakes / rake</span>
              <div className="flex items-center gap-3">
                {onUpsertRake && profile && (
                  <button onClick={() => setEditingRake(profile)} style={{ color: theme.gold, fontSize: 12 }}>
                    Edit
                  </button>
                )}
                {onUpsertRake && (
                  <button onClick={() => setEditingRake("new")} style={{ color: theme.gold, fontSize: 12 }}>
                    + New
                  </button>
                )}
              </div>
            </div>
            <select
              value={rakeProfileId}
              onChange={(e) => setRakeProfileId(e.target.value)}
              className="w-full mt-1 px-3 py-2 rounded-lg outline-none"
              style={field}
            >
              {rakes.map((r) => (
                <option key={r.id} value={r.id}>
                  {r.label}
                </option>
              ))}
            </select>
            {profile && (
              <span style={{ color: "rgba(255,255,255,0.4)", fontSize: 11 }}>
                {rakeSummary(profile)}
              </span>
            )}
          </div>

          <div>
            <div style={{ color: "rgba(255,255,255,0.6)", fontSize: 12, marginBottom: 6 }}>
              Occupied seats (tap to toggle; names optional)
            </div>
            <div className="flex flex-col gap-1.5">
              {seats.map((s, i) => (
                <div key={i} className="flex items-center gap-2">
                  <button
                    onClick={() => toggleSeat(i)}
                    className="rounded-lg shrink-0 flex items-center justify-center"
                    style={{
                      width: 38,
                      height: 34,
                      fontWeight: 700,
                      fontSize: 13,
                      background: s.occupied ? theme.gold : "rgba(255,255,255,0.06)",
                      color: s.occupied ? theme.ink : "rgba(255,255,255,0.4)",
                      border: i + 1 === heroSeat ? "2px solid #1f8a4c" : "none",
                    }}
                  >
                    {i + 1}
                  </button>
                  <input
                    value={i + 1 === heroSeat ? heroName : s.name}
                    disabled={!s.occupied || i + 1 === heroSeat}
                    onChange={(e) => renameSeat(i, e.target.value)}
                    className="flex-1 px-2.5 py-1.5 rounded-lg outline-none"
                    style={{
                      ...field,
                      fontSize: 13,
                      opacity: s.occupied ? 1 : 0.4,
                    }}
                  />
                  <input
                    value={s.stack ?? ""}
                    disabled={!s.occupied}
                    inputMode="numeric"
                    placeholder="stack"
                    onChange={(e) => restack(i, e.target.value)}
                    className="px-2 py-1.5 rounded-lg outline-none text-center"
                    style={{ ...field, fontSize: 12, width: 62, opacity: s.occupied ? 1 : 0.4 }}
                  />
                </div>
              ))}
            </div>
          </div>
        </div>

        <div className="px-4 py-3" style={{ borderTop: "1px solid rgba(255,255,255,0.08)" }}>
          <button
            onClick={submit}
            className="w-full h-12 rounded-xl font-semibold"
            style={{ background: theme.gold, color: theme.ink, fontSize: 15 }}
          >
            Start logging
          </button>
        </div>
      </div>

      {editingRake && (
        <RakeEditor
          init={editingRake === "new" ? null : editingRake}
          rakes={rakes}
          onSave={(p) => {
            onUpsertRake(p);
            setRakeProfileId(p.id);
            setEditingRake(null);
          }}
          onDelete={(id) => {
            onDeleteRake(id);
            if (rakeProfileId === id) {
              const next = rakes.find((r) => r.id !== id);
              if (next) setRakeProfileId(next.id);
            }
            setEditingRake(null);
          }}
          onClose={() => setEditingRake(null)}
        />
      )}
    </div>
  );
}
