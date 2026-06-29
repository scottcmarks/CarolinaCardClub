import { useState } from "react";
import { X } from "lucide-react";
import { DEFAULT_HERO_SEAT, SEAT_COUNT, theme } from "./constants.js";
import { hhmm } from "./lib/cards.js";
import { useHandLogger } from "./hooks/useHandLogger.js";
import SessionBar from "./components/SessionBar.jsx";
import PokerTable from "./components/PokerTable.jsx";
import StatusLine from "./components/StatusLine.jsx";
import Keypad from "./components/Keypad.jsx";
import Actions from "./components/Actions.jsx";
import HistoryPanel from "./components/HistoryPanel.jsx";

export default function App() {
  const h = useHandLogger();
  const [showHistory, setShowHistory] = useState(false);
  const editing = h.editingId !== null;
  const heroSeat = Math.min(
    Math.max(parseInt(h.session.seat, 10) || DEFAULT_HERO_SEAT, 1),
    SEAT_COUNT
  );

  return (
    <div className="min-h-screen w-full flex justify-center" style={{ background: theme.felt }}>
      <div
        className="w-full max-w-sm flex flex-col px-4 pt-4 pb-4 relative"
        style={{ minHeight: "100vh", paddingTop: "max(1rem, env(safe-area-inset-top))", paddingBottom: "max(1rem, env(safe-area-inset-bottom))" }}
      >
        <SessionBar
          session={h.session}
          updateSession={h.updateSession}
          logCount={h.log.length}
          onOpenHistory={() => setShowHistory(true)}
        />

        {editing && h.editingEntry && (
          <div
            className="flex items-center justify-between mb-2 px-2.5 py-1.5 rounded-lg"
            style={{ background: "rgba(201,162,39,0.15)", border: "1px solid rgba(201,162,39,0.5)" }}
          >
            <span style={{ color: theme.textLight, fontSize: 12 }}>Editing hand · {hhmm(h.editingEntry.ts)}</span>
            <button onClick={h.cancelEdit} className="flex items-center gap-1" style={{ color: theme.gold, fontSize: 12 }}>
              <X size={13} /> Cancel
            </button>
          </div>
        )}

        <PokerTable
          cards={h.cards}
          reveals={h.reveals}
          active={h.active}
          heroSeat={heroSeat}
          buttonSeat={Math.min(Math.max(h.session.button || 1, 1), SEAT_COUNT)}
          onSelect={h.selectTarget}
          onSelectSeat={h.selectSeat}
          onRemoveReveal={h.removeReveal}
          onAdvanceButton={h.advanceButton}
        />

        <StatusLine flash={h.flash} pendingRank={h.pendingRank} active={h.active} editing={editing} />

        <Keypad pendingRank={h.pendingRank} usedIds={h.usedIds} onRank={h.pickRank} onSuit={h.pickSuit} />

        <Actions
          pendingRank={h.pendingRank}
          canUndo={h.canUndo}
          anyEntered={h.anyEntered}
          editing={editing}
          onCancelPending={() => h.pickRank(h.pendingRank)}
          onUndo={h.undo}
          onClear={h.clearHand}
          onEnd={() => h.endHand()}
        />

        {showHistory && (
          <HistoryPanel
            log={h.log}
            editingId={h.editingId}
            onClose={() => setShowHistory(false)}
            onEdit={(entry) => { h.loadHand(entry); setShowHistory(false); }}
            onDelete={h.deleteHand}
          />
        )}
      </div>
    </div>
  );
}
