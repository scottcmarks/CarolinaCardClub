import { useState } from "react";
import { Trash2, Plus } from "lucide-react";
import { theme } from "../constants.js";

const field = {
  background: "rgba(255,255,255,0.08)",
  color: theme.textLight,
  fontSize: 14,
  border: "1px solid rgba(255,255,255,0.12)",
};
const Label = ({ children }) => (
  <span style={{ color: "rgba(255,255,255,0.6)", fontSize: 12 }}>{children}</span>
);

const num = (v) => {
  if (v === "" || v == null) return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
};

// Add / edit a single rake profile. `init` = the profile to edit, or null for new.
export default function RakeEditor({ init, rakes, onSave, onDelete, onClose }) {
  const [label, setLabel] = useState(init?.label || "");
  const [venue, setVenue] = useState(init?.venue || "");
  const [sb, setSb] = useState(init?.sb ?? 1);
  const [bb, setBb] = useState(init?.bb ?? 3);
  const [type, setType] = useState(init?.type || "percent");
  const [components, setComponents] = useState(
    (init?.components || [{ percent: 0.1, cap: 7 }]).map((c) => ({
      percent: Math.round((c.percent || 0) * 100),
      cap: c.cap ?? "",
      shortCap: c.shortCap ?? "",
    }))
  );
  const [shortThreshold, setShortThreshold] = useState(init?.shortHandedThreshold ?? "");
  const [dropOnFlopOnly, setDropOnFlopOnly] = useState(!!init?.dropOnFlopOnly);
  const [perHour, setPerHour] = useState(init?.perHour ?? 6);
  const [minHours, setMinHours] = useState(init?.minHours ?? 2);
  const [prepay, setPrepay] = useState(init?.prepay ?? "");
  const [straddle, setStraddle] = useState((init?.straddleAmounts || []).join(", "));

  const setComp = (i, k, v) =>
    setComponents((p) => p.map((c, j) => (j === i ? { ...c, [k]: v } : c)));
  const addComp = () => setComponents((p) => [...p, { percent: 0, cap: "", shortCap: "" }]);
  const delComp = (i) => setComponents((p) => p.filter((_, j) => j !== i));

  const uniqueId = () => {
    if (init?.id) return init.id;
    const base = (label.trim().toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")) || "rake";
    let id = base;
    let k = 2;
    const ids = new Set((rakes || []).map((r) => r.id));
    while (ids.has(id)) id = `${base}-${k++}`;
    return id;
  };

  const save = () => {
    const straddleAmounts = straddle
      .split(/[,\s]+/)
      .map(Number)
      .filter((x) => Number.isFinite(x) && x > 0);
    const base = {
      id: uniqueId(),
      label: label.trim() || "Rake",
      venue: venue.trim(),
      sb: num(sb) ?? 1,
      bb: num(bb) ?? 2,
      type,
      ...(straddleAmounts.length ? { straddleAmounts } : {}),
    };
    let profile;
    if (type === "percent") {
      profile = {
        ...base,
        components: components
          .map((c) => {
            const comp = { percent: (num(c.percent) || 0) / 100, cap: num(c.cap) };
            if (num(c.shortCap) != null) comp.shortCap = num(c.shortCap);
            return comp;
          })
          .filter((c) => c.percent > 0 || c.cap != null),
        shortHandedThreshold: num(shortThreshold) ?? 0,
        dropOnFlopOnly,
      };
    } else if (type === "time") {
      profile = { ...base, perHour: num(perHour) || 0, minHours: num(minHours) || 0, prepay: num(prepay) };
    } else {
      profile = base;
    }
    onSave(profile);
  };

  const TypeBtn = ({ v, children }) => (
    <button
      onClick={() => setType(v)}
      className="flex-1 py-2 rounded-lg font-semibold"
      style={{
        fontSize: 13,
        background: type === v ? theme.gold : "rgba(255,255,255,0.08)",
        color: type === v ? theme.ink : theme.textLight,
      }}
    >
      {children}
    </button>
  );

  return (
    <div className="fixed inset-0 z-[80] flex justify-center" style={{ background: "rgba(0,0,0,0.7)" }}>
      <div className="w-full max-w-sm flex flex-col overflow-y-auto" style={{ background: theme.panel }}>
        <div
          className="px-4 py-3 flex items-center justify-between"
          style={{ borderBottom: "1px solid rgba(255,255,255,0.08)" }}
        >
          <span style={{ color: theme.textLight, fontSize: 16, fontWeight: 700 }}>
            {init ? "Edit rake" : "New rake"}
          </span>
          <button onClick={onClose} style={{ color: "rgba(255,255,255,0.6)", fontSize: 13 }}>
            Cancel
          </button>
        </div>

        <div className="px-4 py-3 flex flex-col gap-3">
          <label className="flex flex-col gap-1">
            <Label>Name (shown in the picker)</Label>
            <input value={label} onChange={(e) => setLabel(e.target.value)} placeholder="Danville 1-3"
              className="px-3 py-2 rounded-lg outline-none" style={field} />
          </label>
          <div className="grid grid-cols-3 gap-2">
            <label className="flex flex-col gap-1">
              <Label>Venue</Label>
              <input value={venue} onChange={(e) => setVenue(e.target.value)}
                className="px-3 py-2 rounded-lg outline-none" style={field} />
            </label>
            <label className="flex flex-col gap-1">
              <Label>Small blind</Label>
              <input value={sb} inputMode="numeric" onChange={(e) => setSb(e.target.value)}
                className="px-3 py-2 rounded-lg outline-none text-center" style={field} />
            </label>
            <label className="flex flex-col gap-1">
              <Label>Big blind</Label>
              <input value={bb} inputMode="numeric" onChange={(e) => setBb(e.target.value)}
                className="px-3 py-2 rounded-lg outline-none text-center" style={field} />
            </label>
          </div>

          <label className="flex flex-col gap-1">
            <Label>Straddle $ (UTG; comma-separated, blank = none)</Label>
            <input value={straddle} inputMode="numeric" placeholder="e.g. 5   or   4, 5"
              onChange={(e) => setStraddle(e.target.value)}
              className="px-3 py-2 rounded-lg outline-none" style={field} />
          </label>

          <div className="flex gap-2">
            <TypeBtn v="percent">Pot rake</TypeBtn>
            <TypeBtn v="time">Time</TypeBtn>
            <TypeBtn v="none">None</TypeBtn>
          </div>

          {type === "percent" && (
            <div className="flex flex-col gap-2">
              <Label>Rake components (each capped independently)</Label>
              {components.map((c, i) => (
                <div key={i} className="flex items-end gap-2">
                  <label className="flex flex-col gap-1" style={{ width: 58 }}>
                    <Label>%</Label>
                    <input value={c.percent} inputMode="numeric" onChange={(e) => setComp(i, "percent", e.target.value)}
                      className="px-2 py-2 rounded-lg outline-none text-center" style={field} />
                  </label>
                  <label className="flex flex-col gap-1" style={{ width: 62 }}>
                    <Label>cap $</Label>
                    <input value={c.cap} inputMode="numeric" onChange={(e) => setComp(i, "cap", e.target.value)}
                      className="px-2 py-2 rounded-lg outline-none text-center" style={field} />
                  </label>
                  <label className="flex flex-col gap-1" style={{ width: 74 }}>
                    <Label>≤N cap</Label>
                    <input value={c.shortCap} inputMode="numeric" placeholder="—" onChange={(e) => setComp(i, "shortCap", e.target.value)}
                      className="px-2 py-2 rounded-lg outline-none text-center" style={field} />
                  </label>
                  <button onClick={() => delComp(i)} className="pb-2" style={{ color: "rgba(255,255,255,0.4)" }}>
                    <Trash2 size={15} />
                  </button>
                </div>
              ))}
              <button onClick={addComp} className="flex items-center gap-1 self-start"
                style={{ color: theme.gold, fontSize: 12.5 }}>
                <Plus size={14} /> Add component
              </button>
              <div className="grid grid-cols-2 gap-2 items-end mt-1">
                <label className="flex flex-col gap-1">
                  <Label>Short-handed at ≤N</Label>
                  <input value={shortThreshold} inputMode="numeric" placeholder="5" onChange={(e) => setShortThreshold(e.target.value)}
                    className="px-3 py-2 rounded-lg outline-none text-center" style={field} />
                </label>
                <button onClick={() => setDropOnFlopOnly((v) => !v)} className="py-2 rounded-lg font-semibold"
                  style={{ fontSize: 12.5, background: dropOnFlopOnly ? theme.gold : "rgba(255,255,255,0.08)", color: dropOnFlopOnly ? theme.ink : theme.textLight }}>
                  No flop, no drop {dropOnFlopOnly ? "✓" : ""}
                </button>
              </div>
            </div>
          )}

          {type === "time" && (
            <div className="grid grid-cols-3 gap-2">
              <label className="flex flex-col gap-1">
                <Label>$ / hour</Label>
                <input value={perHour} inputMode="numeric" onChange={(e) => setPerHour(e.target.value)}
                  className="px-3 py-2 rounded-lg outline-none text-center" style={field} />
              </label>
              <label className="flex flex-col gap-1">
                <Label>Min hours</Label>
                <input value={minHours} inputMode="numeric" onChange={(e) => setMinHours(e.target.value)}
                  className="px-3 py-2 rounded-lg outline-none text-center" style={field} />
              </label>
              <label className="flex flex-col gap-1">
                <Label>Prepay $</Label>
                <input value={prepay} inputMode="numeric" placeholder="—" onChange={(e) => setPrepay(e.target.value)}
                  className="px-3 py-2 rounded-lg outline-none text-center" style={field} />
              </label>
            </div>
          )}

          {type === "none" && (
            <div style={{ color: "rgba(255,255,255,0.5)", fontSize: 12.5 }}>
              No house cut — nothing is taken per hand or per session.
            </div>
          )}
        </div>

        <div className="px-4 py-3 flex gap-2" style={{ borderTop: "1px solid rgba(255,255,255,0.08)" }}>
          {init && onDelete && (
            <button onClick={() => onDelete(init.id)} className="h-11 px-4 rounded-xl"
              style={{ background: "rgba(138,31,31,0.8)", color: "#fff", fontSize: 14 }}>
              <Trash2 size={16} />
            </button>
          )}
          <button onClick={save} className="flex-1 h-11 rounded-xl font-semibold"
            style={{ background: theme.gold, color: theme.ink, fontSize: 15 }}>
            Save rake
          </button>
        </div>
      </div>
    </div>
  );
}
