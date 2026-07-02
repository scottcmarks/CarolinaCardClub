import { useState } from "react";
import { X } from "lucide-react";
import { theme } from "./constants.js";
import { hhmm } from "./lib/cards.js";
import { toCall } from "./lib/betting.js";
import { useHandLogger } from "./hooks/useHandLogger.js";
import SessionBar from "./components/SessionBar.jsx";
import PokerTable from "./components/PokerTable.jsx";
import StatusLine from "./components/StatusLine.jsx";
import Keypad from "./components/Keypad.jsx";
import ActionPad from "./components/ActionPad.jsx";
import Actions from "./components/Actions.jsx";
import HistoryPanel from "./components/HistoryPanel.jsx";
import Onboarding from "./components/Onboarding.jsx";

export default function App() {
  const h = useHandLogger();
  const [showHistory, setShowHistory] = useState(false);
  const [showSetup, setShowSetup] = useState(false);
  const editing = h.editingId !== null;
  const needsOnboard = !h.session.onboarded;
  const betting = h.mode === "betting";

  return (
    <div className="min-h-screen w-full flex justify-center" style={{ background: theme.felt }}>
      <div
        className="w-full max-w-sm flex flex-col px-4 pt-4 pb-4 relative"
        style={{
          minHeight: "100vh",
          paddingTop: "max(1rem, env(safe-area-inset-top))",
          paddingBottom: "max(1rem, env(safe-area-inset-bottom))",
        }}
      >
        <div
          className="text-center mb-1"
          style={{ color: "rgba(255,255,255,0.5)", fontSize: 10.5, letterSpacing: "0.16em", fontWeight: 700 }}
        >
          CCC HAND LOGGER
        </div>

        <SessionBar
          session={h.session}
          logCount={h.log.length}
          onOpenHistory={() => setShowHistory(true)}
          onOpenSetup={() => setShowSetup(true)}
        />

        {editing && h.editingEntry && (
          <div
            className="flex items-center justify-between mb-2 px-2.5 py-1.5 rounded-lg"
            style={{ background: "rgba(201,162,39,0.15)", border: "1px solid rgba(201,162,39,0.5)" }}
          >
            <span style={{ color: theme.textLight, fontSize: 12 }}>
              Editing hand · {hhmm(h.editingEntry.ts)}
            </span>
            <div className="flex items-center gap-3">
              <button onClick={h.restartBetting} style={{ color: theme.gold, fontSize: 12 }}>
                Re-enter betting
              </button>
              <button onClick={h.cancelEdit} className="flex items-center gap-1" style={{ color: theme.gold, fontSize: 12 }}>
                <X size={13} /> Cancel
              </button>
            </div>
          </div>
        )}

        <PokerTable
          cards={h.cards}
          reveals={h.reveals}
          heroRevealed={h.heroRevealed}
          active={h.active}
          mode={h.mode}
          phase={h.phase}
          bet={h.bet}
          seats={h.seats}
          positions={h.positions}
          heroSeat={h.heroSeat}
          heroName={h.session.heroName}
          buttonSeat={h.button}
          onSelectCommunity={h.selectTarget}
          onTapHeroCard={h.tapHeroCard}
          onSeatAct={h.tapSeatToAct}
          onSelectSeat={h.selectSeat}
          onRemoveReveal={h.removeReveal}
          onSeatNew={(n) => h.setSeatOccupied(n, true)}
          onAdvanceButton={h.advanceButton}
        />

        <StatusLine
          flash={h.flash}
          pendingRank={h.pendingRank}
          active={h.active}
          mode={h.mode}
          phase={h.phase}
          dealingStreet={h.dealingStreet}
          bet={h.bet}
          seats={h.seats}
          heroSeat={h.heroSeat}
          heroName={h.session.heroName}
          editing={editing}
        />

        <div style={{ minHeight: 212 }} className="flex flex-col justify-end">
          {betting ? (
            <div
              className="rounded-xl px-3 py-3 mb-1 flex items-center justify-between"
              style={{ background: "rgba(0,0,0,0.18)" }}
            >
              <div className="flex flex-col">
                <span style={{ color: theme.gold, fontSize: 12, fontWeight: 700 }}>
                  {h.phase[0].toUpperCase() + h.phase.slice(1)} betting
                </span>
                <span style={{ color: "rgba(255,255,255,0.55)", fontSize: 11.5 }}>
                  {h.bet.actor != null
                    ? `Tap the pad to act · or tap a later seat to skip-fold`
                    : "Round complete"}
                </span>
              </div>
              <div className="text-right">
                <div style={{ color: theme.textLight, fontSize: 13, fontWeight: 700 }}>Pot ${h.bet.pot}</div>
                {h.bet.actor != null && toCall(h.bet, h.bet.actor) > 0 && (
                  <div style={{ color: "rgba(255,255,255,0.55)", fontSize: 11 }}>
                    to call ${toCall(h.bet, h.bet.actor)}
                  </div>
                )}
              </div>
            </div>
          ) : (
            <Keypad
              pendingRank={h.pendingRank}
              usedIds={h.usedIds}
              onRank={h.pickRank}
              onSuit={h.pickSuit}
            />
          )}
        </div>

        <Actions
          pendingRank={h.pendingRank}
          canUndo={h.canUndo}
          anyEntered={h.anyEntered}
          editing={editing}
          onCancelPending={() => h.pickRank(h.pendingRank)}
          onUndo={h.undo}
          onClear={h.clearHand}
          onEnd={h.endHand}
        />

        {showHistory && (
          <HistoryPanel
            log={h.log}
            editingId={h.editingId}
            onClose={() => setShowHistory(false)}
            onEdit={(entry) => {
              h.loadHand(entry);
              setShowHistory(false);
            }}
            onDelete={h.deleteHand}
          />
        )}
      </div>

      {betting && h.bet.actor != null && (
        <ActionPad
          actorSeat={h.bet.actor}
          actorLabel={`${
            h.bet.actor === h.heroSeat ? h.session.heroName || "You" : h.seats[h.bet.actor - 1]?.name || "Seat " + h.bet.actor
          } · ${h.positions[h.bet.actor] || ""}`}
          pot={h.bet.pot}
          toCall={toCall(h.bet, h.bet.actor)}
          currentBet={h.bet.currentBet}
          onAct={h.act}
        />
      )}

      {(needsOnboard || showSetup) && (
        <Onboarding
          session={h.session}
          rakes={h.rakes}
          onDone={(patch) => {
            h.completeOnboarding(patch);
            setShowSetup(false);
          }}
          onClose={needsOnboard ? null : () => setShowSetup(false)}
        />
      )}
    </div>
  );
}
