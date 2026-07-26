import { useState, useEffect } from "react";
import { X } from "lucide-react";
import { theme } from "./constants.js";
import { hhmm } from "./lib/cards.js";
import { toCall } from "./lib/betting.js";
import { blockCharge } from "./lib/rake.js";
import { useHandLogger } from "./hooks/useHandLogger.js";
import SessionBar from "./components/SessionBar.jsx";
import PokerTable from "./components/PokerTable.jsx";
import StatusLine from "./components/StatusLine.jsx";
import Keypad from "./components/Keypad.jsx";
import ActionPad from "./components/ActionPad.jsx";
import Actions from "./components/Actions.jsx";
import HistoryPanel from "./components/HistoryPanel.jsx";
import Onboarding from "./components/Onboarding.jsx";
import SessionSummary from "./components/SessionSummary.jsx";
import PlayerMenu from "./components/PlayerMenu.jsx";

export default function App() {
  const h = useHandLogger();
  const [showHistory, setShowHistory] = useState(false);
  const [showSetup, setShowSetup] = useState(false);
  const [showSession, setShowSession] = useState(false);
  const [menuSeat, setMenuSeat] = useState(null);
  const [moving, setMoving] = useState(false);
  const [winners, setWinners] = useState([]);
  const [bombPick, setBombPick] = useState(null); // null | seat[] — bomb-pot participant picker
  const sittingOut = h.session.sittingOut;

  // on settling, pre-select the evaluated winner(s); the tap can still override
  useEffect(() => {
    setWinners(h.settling ? h.showdownEval?.winners || [] : []);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [h.settling]);
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
          profile={h.rakeProfile}
          logCount={h.log.length}
          onOpenHistory={() => setShowHistory(true)}
          onOpenSetup={() => setShowSetup(true)}
          onOpenSession={() => setShowSession(true)}
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

        {(moving || sittingOut) && (
          <div
            className="flex items-center justify-between mb-2 px-2.5 py-1.5 rounded-lg"
            style={{ background: "rgba(31,138,76,0.15)", border: "1px solid rgba(31,138,76,0.5)" }}
          >
            <span style={{ color: "#7fe0a6", fontSize: 12 }}>
              {moving ? "Tap an empty seat to move there" : "You're standing — tap an empty seat to sit down"}
            </span>
            {moving && (
              <button onClick={() => setMoving(false)} style={{ color: theme.gold, fontSize: 12 }}>
                Cancel
              </button>
            )}
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
          dealt={h.session.dealt}
          tableShape={h.session.tableShape}
          geo={h.geo}
          settling={h.settling}
          selectedWinners={winners}
          sittingOut={sittingOut}
          moving={moving}
          onSelectCommunity={h.selectTarget}
          onTapHeroCard={h.tapHeroCard}
          onSeatAct={h.tapSeatToAct}
          onSelectSeat={h.selectSeat}
          onRemoveReveal={h.removeReveal}
          onAdvanceButton={h.advanceButton}
          onAwardWinner={(n) =>
            setWinners((w) => (w.includes(n) ? w.filter((x) => x !== n) : [...w, n]))
          }
          onOpenMenu={setMenuSeat}
          onMoveHere={(n) => {
            h.moveHeroTo(n);
            setMoving(false);
          }}
          onSitHere={h.heroSitDown}
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
          holeStart={h.holeStart}
          editing={editing}
        />

        <div style={{ minHeight: 212 }} className="flex flex-col justify-end">
          {h.settling ? (
            <div
              className="rounded-xl px-3 py-3 mb-1"
              style={{ background: "rgba(31,138,76,0.15)", border: "1px solid rgba(31,138,76,0.5)" }}
            >
              <div style={{ color: "#7fe0a6", fontSize: 13, fontWeight: 700 }}>
                {h.showdownEval
                  ? `${h.showdownEval.winners.length > 1 ? "Chop" : "Winner"}: ${h.showdownEval.best} · Pot $${h.bet.pot}`
                  : `Tap the winner${winners.length > 1 ? "s (chop)" : ""} · Pot $${h.bet.pot}`}
              </div>
              <div style={{ color: "rgba(255,255,255,0.5)", fontSize: 11, marginTop: 2 }}>
                {h.showdownEval
                  ? "Read from the shown cards — tap a seat to override, then Award."
                  : "Enter the shown hands (tap a seat), or tap the winner directly."}
              </div>
              <div className="flex gap-2 mt-2">
                <button
                  onClick={h.cancelSettle}
                  className="h-9 px-3 rounded-lg"
                  style={{ background: "rgba(255,255,255,0.08)", color: theme.textLight, fontSize: 13 }}
                >
                  Back
                </button>
                <button
                  onClick={h.skipSettle}
                  className="h-9 px-3 rounded-lg"
                  style={{ background: "rgba(255,255,255,0.08)", color: theme.textLight, fontSize: 13 }}
                >
                  No result
                </button>
                <button
                  onClick={() => h.awardTo(winners)}
                  disabled={winners.length === 0}
                  className="flex-1 h-9 rounded-lg font-semibold"
                  style={{
                    background: winners.length ? "#1f8a4c" : "rgba(255,255,255,0.08)",
                    color: winners.length ? "#fff" : "rgba(255,255,255,0.35)",
                    fontSize: 13,
                  }}
                >
                  {winners.length > 1 ? `Split among ${winners.length}` : "Award pot"}
                </button>
              </div>
            </div>
          ) : betting ? (
            <>
              {h.canBombPot && (
                <button
                  onClick={() => setBombPick(h.seats.map((s, i) => (s.occupied ? i + 1 : null)).filter(Boolean))}
                  className="w-full h-9 rounded-lg font-semibold active:scale-95 mb-1"
                  style={{
                    background: "rgba(201,70,31,0.2)",
                    color: "#ff9d6e",
                    border: "1px solid rgba(201,70,31,0.55)",
                    fontSize: 13,
                  }}
                >
                  💣 Bomb pot — ${(h.rakeProfile.bombPot?.ante || 0) + (h.rakeProfile.bombPot ? blockCharge(h.rakeProfile) : 0)} a head
                </button>
              )}
              {h.canStraddle && (
                <div className="flex gap-2 mb-1">
                  {h.straddleAmounts.map((amt) => (
                    <button
                      key={amt}
                      onClick={() => h.straddle(amt)}
                      className="flex-1 h-9 rounded-lg font-semibold active:scale-95"
                      style={{
                        background: "rgba(201,162,39,0.22)",
                        color: theme.gold,
                        border: "1px solid rgba(201,162,39,0.5)",
                        fontSize: 13,
                      }}
                    >
                      Straddle ${amt}
                    </button>
                  ))}
                </div>
              )}
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
            </>
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
          stack={(() => {
            const s = h.stackOf(h.bet.actor);
            return s == null ? null : Math.max(0, s - (h.bet.totalCommitted[h.bet.actor] || 0));
          })()}
          toCall={toCall(h.bet, h.bet.actor)}
          currentBet={h.bet.currentBet}
          potMaxTo={h.potMaxTo}
          onAct={h.act}
          onAllIn={h.allIn}
        />
      )}

      {bombPick && (
        <div
          className="fixed inset-0 z-[88] flex items-center justify-center px-6"
          style={{ background: "rgba(0,0,0,0.75)" }}
          onClick={() => setBombPick(null)}
        >
          <div
            className="w-full max-w-xs rounded-2xl p-4"
            style={{ background: theme.panel, border: "1px solid rgba(201,70,31,0.55)" }}
            onClick={(e) => e.stopPropagation()}
          >
            <div style={{ color: "#ff9d6e", fontSize: 14, fontWeight: 800 }}>💣 Bomb pot</div>
            <div style={{ color: "rgba(255,255,255,0.6)", fontSize: 12, marginTop: 4 }}>
              ${h.rakeProfile.bombPot?.ante || 0} + ${blockCharge(h.rakeProfile)} collection = $
              {(h.rakeProfile.bombPot?.ante || 0) + blockCharge(h.rakeProfile)} a head. Tap who's
              in — sit-outs pay the ${blockCharge(h.rakeProfile)} collection.
            </div>
            <div className="grid grid-cols-3 gap-1.5 mt-3">
              {h.seats.map((s, i) =>
                s.occupied ? (
                  <button
                    key={i}
                    onClick={() =>
                      setBombPick((p) =>
                        p.includes(i + 1) ? p.filter((x) => x !== i + 1) : [...p, i + 1]
                      )
                    }
                    className="h-10 rounded-lg font-semibold active:scale-95"
                    style={{
                      background: bombPick.includes(i + 1) ? "rgba(201,70,31,0.45)" : "rgba(255,255,255,0.07)",
                      color: bombPick.includes(i + 1) ? "#ffb08a" : "rgba(255,255,255,0.45)",
                      border: bombPick.includes(i + 1)
                        ? "1px solid rgba(201,70,31,0.8)"
                        : "1px solid rgba(255,255,255,0.12)",
                      fontSize: 12,
                    }}
                  >
                    S{i + 1}
                    {i + 1 === h.heroSeat ? " ·you" : ""}
                  </button>
                ) : null
              )}
            </div>
            <div
              style={{ color: theme.gold, fontSize: 12, fontWeight: 700, marginTop: 8 }}
            >
              {bombPick.length} in → ${bombPick.length * ((h.rakeProfile.bombPot?.ante || 0) + blockCharge(h.rakeProfile))} at the flop
            </div>
            <div className="flex gap-2 mt-3">
              <button
                onClick={() => setBombPick(null)}
                className="h-10 px-4 rounded-lg"
                style={{ background: "rgba(255,255,255,0.08)", color: theme.textLight, fontSize: 13 }}
              >
                Cancel
              </button>
              <button
                onClick={() => {
                  h.startBombPot(bombPick.sort((a, b) => a - b));
                  setBombPick(null);
                }}
                disabled={bombPick.length < 2}
                className="flex-1 h-10 rounded-lg font-bold"
                style={{
                  background: bombPick.length >= 2 ? "#c9461f" : "rgba(255,255,255,0.08)",
                  color: bombPick.length >= 2 ? "#fff" : "rgba(255,255,255,0.35)",
                  fontSize: 13,
                }}
              >
                Deal the bomb pot
              </button>
            </div>
          </div>
        </div>
      )}

      {h.illegalPrompt && (
        <div
          className="fixed inset-0 z-[90] flex items-center justify-center px-6"
          style={{ background: "rgba(0,0,0,0.75)" }}
        >
          <div
            className="w-full max-w-xs rounded-2xl p-4"
            style={{ background: theme.panel, border: "1px solid rgba(255,120,120,0.6)" }}
          >
            <div className="flex items-center gap-2 mb-2">
              <span style={{ fontSize: 18 }}>⚠️</span>
              <span style={{ color: "#ff9a9a", fontSize: 15, fontWeight: 700 }}>
                That looks illegal
              </span>
            </div>
            <div style={{ color: theme.textLight, fontSize: 13, lineHeight: 1.45, marginBottom: 14 }}>
              {h.illegalPrompt.reason}
            </div>
            <div className="flex gap-2">
              <button
                onClick={h.cancelIllegal}
                className="flex-1 h-11 rounded-xl font-semibold"
                style={{ background: "rgba(255,255,255,0.1)", color: theme.textLight, fontSize: 14 }}
              >
                Cancel
              </button>
              <button
                onClick={h.confirmIllegal}
                className="flex-1 h-11 rounded-xl font-semibold"
                style={{ background: "rgba(138,31,31,0.9)", color: "#fff", fontSize: 14 }}
              >
                Enter anyway
              </button>
            </div>
          </div>
        </div>
      )}

      {menuSeat != null && (
        <PlayerMenu
          seatNum={menuSeat}
          isHero={menuSeat === h.heroSeat && !sittingOut}
          occupied={!!h.seats[menuSeat - 1]?.occupied}
          name={h.seats[menuSeat - 1]?.name || ""}
          stack={h.seats[menuSeat - 1]?.stack ?? null}
          onSetStack={h.setSeatStack}
          onRename={h.setSeatName}
          onEnterCards={(n) => {
            h.enterCards(n);
            setMenuSeat(null);
          }}
          onStartMove={() => {
            setMoving(true);
            setMenuSeat(null);
          }}
          onStandUp={() => {
            h.heroStandUp();
            setMenuSeat(null);
          }}
          onVacate={(n) => {
            h.vacateSeat(n);
            setMenuSeat(null);
          }}
          onSeat={(n) => {
            h.seatVillain(n);
            setMenuSeat(null);
          }}
          onClose={() => setMenuSeat(null)}
        />
      )}

      {showSession && (
        <SessionSummary
          session={h.session}
          log={h.log}
          profile={h.rakeProfile}
          onSetStart={h.setSessionStart}
          onSetPrepaid={h.setPrepaid}
          onBumpCollections={h.bumpCollections}
          onEndSession={h.endSession}
          onStartNew={() => {
            h.startNewSession();
          }}
          onClose={() => setShowSession(false)}
        />
      )}

      {(needsOnboard || showSetup) && (
        <Onboarding
          session={h.session}
          rakes={h.rakes}
          onUpsertRake={h.upsertRake}
          onDeleteRake={h.deleteRake}
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
