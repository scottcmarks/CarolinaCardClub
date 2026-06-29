# Carolina Card Club — Session Changes (2026-03-17, continued)

## Build
- `flutter clean` + full rebuild after Flutter/Dart upgrade; all targets rebuilt cleanly

## Tablet — Dynamic Seat Capacity
- `client/lib/pages/tablet_table_page.dart`: tablets now default to 8 seats regardless of server capacity
- `_effectiveCapacities: Map<int,int>` in state tracks per-table overrides
- `_getEffectiveCapacity` = `max(stored, highestOccupiedSeat)` — never hides occupied seats
- Settings gear (PopupMenuButton, replaces old reassign IconButton) shows Add/Remove seat and Change Table
- Add seat: available when `effectiveCap < table.capacity`; Remove seat: when `effectiveCap >= 9` and highest seat empty
- Effective capacity used for main oval and move-seat dialog

## Maintenance
- `server/delete_after_mar1.sh`: bash/sqlite3 script to delete Session and Payment rows with epoch ≥ 2026-03-01; shows counts and prompts for confirmation before deleting

## Diagnosis
- "no such table PokerTable" errors caused by server being run from wrong directory; server must be launched from `server/` so `Directory.current` resolves `CarolinaCardClub.db` correctly

---

# Carolina Card Club — Session Changes (2026-03-17)

## Minimum Seating Balance — New Setting
- `shared/constants.dart`: added `Shared.defaultMinSeatingBalance = 0`
- `server/carolina_card_club_server.dart`: added `Min_Seating_Balance INTEGER DEFAULT 0` column to `System_State` schema + migration; extended `_updateDefaultsHandler` to accept `minSeatBalance`
- `client/lib/services/api_service.dart`: `updateDefaultSessionTime` now sends `minSeatBalance`
- `client/lib/providers/api_provider.dart`: added `minSeatingBalance` field, read from `GET /state`, threaded through `updateDefaultSessionTime`
- `client/lib/pages/settings_page.dart`: added "Table Rules" section with "Minimum Seating Balance ($)" signed-int field; note on floor manager toggle

## Tablet Seating — No Payment UI
- `client/lib/widgets/start_session_dialog.dart`: added `isTablet: bool = false`; in tablet mode: no payment text field, no negative-balance warning box; prepay switch shown only when balance ≥ prepay cost
- `client/lib/pages/tablet_table_page.dart`: balance check before showing dialog — if `balance < api.minSeatingBalance`, shows error AlertDialog directing player to admin; passes `isTablet: true` to `StartSessionDialog`

## Seat Color States — Balance-Based Flashing
- `client/lib/widgets/table_oval_widget.dart`: added `SeatState.lowBalance` (flashing yellow); `overdue` threshold changed from `balance <= 0` to `balance < 0`
- `client/lib/pages/tablet_table_page.dart`: `_getSeatState` updated — `balance < 0` → overdue (flash red); `balance <= minSeatingBalance` → lowBalance (flash yellow); time-based warning (solid amber) only above minimum

## Tablet Auto-Discovery
- `client/lib/shells/tablet_shell.dart`: complete rewrite; `TabletShell` now routes all non-connected states (connecting/failed/disconnected) to `_ServerSearchScreen` — prevents `DbConnectionProvider`'s reconnect loop from destroying mid-scan
- `_ServerSearchScreen`: new StatefulWidget; watches `DbConnectionProvider` via `didChangeDependencies`, starts scan on first failure (not immediately); tries saved IP first then full subnet scan via existing `SubnetScanner`; on success updates `AppSettingsProvider` (proxy provider auto-reconnects WebSocket); on failure shows manual IP field + "Retry Scan" / "Connect" buttons
- 8-second fallback timer ensures scan starts even if failure event is missed

---

# Carolina Card Club — Session Changes (2026-03-12)

## Tablet UI — Full-Screen Immersive Mode
- `client/lib/main_tablet.dart`: added `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)` to hide Android status/nav bars on launch

## Tablet UI — Transparent AppBar
- `tablet_table_page.dart`: AppBar made fully transparent (`backgroundColor: transparent`, `elevation: 0`, `surfaceTintColor: transparent`)
- `extendBodyBehindAppBar: true` — table oval fills full screen height
- Title: replaced `Text(tableName)` with `CCCBannerA.png` logo (height 72, upper-left)
- Logo shifted down via `Transform.translate(Offset(0, 21))` so its top aligns with the clock pill top
- `toolbarHeight: 96` to accommodate logo + offset
- Prev/next table navigation chips remain flanking the logo

## Table Oval — Seat Sizing (Proportional to Screen)
- `table_oval_widget.dart`: seat dimensions are now computed from orbit geometry rather than hardcoded
- `seatH = (min(radiusX, radiusY) × orbitScale × 2 × sin(π/seats) × 0.70).clamp(60, 180)`
- `seatW = seatH × 1.612` — both tablets now get appropriately sized seats
- Selector mode (move-seat dialog) stays fixed at 120×75

## Table Oval — Font Sizing (Proportional to Seat)
- All tablet seat font sizes are now ratios of `seatH` — scale automatically with screen size
- Player name: `seatH × 0.150`; detail line (elapsed/balance): `seatH × 0.107`; empty seat number: `seatH × 0.296`

## Table Oval — Seat Content Layout
- Prepaid seats: show name + "prepaid" label; elapsed time omitted
- Non-prepaid seats: name on line 1; `"Xh00m  Bal: $X"` combined on line 2

## Table Oval — Table Name Label
- Color: carolina blue (`0xFF7BAFD4`), opacity 0.50 (up from 0.25), no shadow
- Font size: 40 (doubled from 20)

---

# Carolina Card Club — Session Changes (2026-03-09, continued)

## macOS Sequoia Local Network Connectivity Fix
- Root cause: dart:io BSD sockets blocked by macOS Sequoia Local Network Privacy for remote LAN hosts
- **Fix**: Added `cupertino_http: ^2.0.0` to `client/pubspec.yaml` and `db_connection/pubspec.yaml`
- `client/lib/services/api_service.dart`: switched from global `http.get/post` to a `_client` instance; uses `CupertinoClient.defaultSessionConfiguration()` on macOS/iOS (NSURLSession), `http.Client()` elsewhere
- `db_connection/lib/providers/db_connection_provider.dart`: uses `CupertinoWebSocket.connect()` + `AdapterWebSocketChannel` on macOS/iOS; `IOWebSocketChannel` on other platforms
- `macos/Runner/Info.plist`: added `NSLocalNetworkUsageDescription`
- `macos/Runner/AppDelegate.swift`: added NWConnection probe on startup to prime network path / trigger permission dialog

## Build & Deployment
- Added `bin/build_and_install_all`: builds macOS + Android release APK, installs APK to tablets k and j via adb

## Infrastructure
- Populated `CarolinaCardClub.db` on errol (.67) via `scp` — server had empty DB on first run

---

# Carolina Card Club — Session Changes (2026-03-08/09)

## AppBar Redesign
- Logo (`CCCBannerA.png`) in leading position, fills AppBar height, `leadingWidth: 220`
- Clock (`RealTimeClock`) centered via `flexibleSpace` across full AppBar width (not between leading/actions)
- Settings gear opens `PopupMenuButton` with: Open/Close Club Session, Reload, More Settings
- Removed standalone refresh button, Switch widget, and settings IconButton from AppBar

## Frosted Clock Widget (`real_time_clock.dart`)
- Replaced plain text clock with frosted glass pill: `BackdropFilter` blur, translucent fill, rim border
- Format: `MM/dd/yy — HH:mm:ss` (date left, time right)
- `FontFeature.tabularFigures()` eliminates size twitching when digits change
- Reads `TimeProvider` directly; turns orange when clock offset is active

## Brand Colors
- Added to `shared/lib/src/constants.dart`:
  - `carolinaBluePrimary = 0xFF4B9CD3` (Pantone 542)
  - `carolinaBlueDigital = 0xFF7BAFD4` (Pantone 278)
  - `carolinaBlue = carolinaBlueDigital` (alias used throughout)
- AppBar theme: `backgroundColor: Color(Shared.carolinaBlue)`, `foregroundColor: Colors.white`

## Player Cards (`player_card.dart`, `player_panel.dart`)
- Font: `titleLarge` (22sp) → 18sp `w500`; `dense: true` + `VisualDensity.compact`; vertical margin 4→2px
- Card color now uses **dynamic balance** (not static `player.balance`), so running-session costs reflected
- Negative balance: `red.shade100` → `red.shade200`
- Removed balance dollar amount display from card trailing
- Added active/inactive fence: 5px solid `grey.shade400` box between `isActive=1` and `isActive=0` players
- Seat button: if player already has running session, just select them instead of starting seating flow

## Session Panel (`session_panel.dart`)
- Running sessions now show elapsed time row (`MM/dd/yy HH:mm • XXhYYm`) same as completed sessions
- Uses `Consumer<TimeProvider>` for live elapsed time on running sessions
- Removed "(Running)" label from subtitle — green color is sufficient
- Header: collapsed into single row with toggle icon after count (`Active Sessions: 4 [toggle]`); subtitle row removed

## PlayerPickerDialog (`player_picker_dialog.dart`)
- Removed balance display and `TimeProvider` dependency
- Replaced `ListView.builder` with `SingleChildScrollView` + `Column` to fix `IntrinsicWidth` crash
- Wrapped in `Flexible` to prevent overflow
- Added active/inactive fence (same style as player panel)
- Removed `SizedBox(width: double.maxFinite)` so dialog sizes to content width

## Logo
- Switched from `CCCBanner.png` (white background) to `CCCBannerA.png` (transparent, GIMP Color to Alpha)

---

# Carolina Card Club — Session Changes (2026-06-29) — poker-hand-logger redesign

## Build / deps
- Installed **Tailwind v4** (`tailwindcss` + `@tailwindcss/vite`) — root cause of "buttons crammed left": every utility class was inert because Tailwind had never been added.
- Wired `@tailwindcss/vite` into `vite.config.js`; added `@import "tailwindcss";` at top of `src/index.css`.

## Keypad (`src/components/Keypad.jsx`)
- Rewrote: **3-row rank grid** `A K Q J T / 9 8 7 6 5 / 4 3 2`, bottom row centered via explicit `gridColumn`, 58px buttons.
- Suit chooser → **fixed-position popover centered on the tapped rank button** (overlays the keypad rather than docking below it). 64px suit buttons, viewport-clamped, transparent backdrop dismisses.

## Poker Table (`src/components/PokerTable.jsx` — NEW; replaces `Board` + `Reveals`)
- Felt oval (flattened: `RX=46`, `RY=34`), brown rail, dealer notch at top.
- 9 seats CCW from top → seat 1 upper-right, seat 5 across from dealer at bottom, seat 9 upper-left (matches the user's club layout).
- Hero seat (`heroSeat` from `session.seat`, default 2): two hole-card slots with gold accent.
- Villain seats: tappable empty chip → creates reveal via new `selectSeat` action; populated seats show their two cards + `S{n} · POS` + remove button.
- Community cards centered on the felt: flop · 14px · turn · 14px · river.
- **Dealer button**: gold-ringed "D" chip placed inboard of the button seat; auto-advances +1 each saved hand; tap to force-advance one seat. Persisted as `session.button`.
- **Position labels** (BTN/SB/BB/UTG/UTG+1/MP/LJ/HJ/CO) rendered under every seat, computed from the button seat.

## Hook (`src/hooks/useHandLogger.js`)
- Removed auto-end-on-hero-completion. Hand now saves only on explicit End Hand (so villain reveals collected after showdown).
- After filling either hero hole card, selection stays on hero (advances to partner slot) instead of `firstEmpty` jumping back to community.
- Added `selectSeat(n)`, `setButton(n)`, `advanceButton()`. `endHand` advances `session.button` by 1 mod 9 on save and writes `button` into the saved log entry.

## Constants / storage
- `src/constants.js`: added `RANK_ROWS`, `SEAT_COUNT=9`, `DEFAULT_HERO_SEAT=2`, `POSITIONS_9`, `tableTheme`.
- `src/lib/storage.js`: extended `loadSession` to include `button` (default 1).

## Removed
- `src/components/Board.jsx`, `src/components/Reveals.jsx` (subsumed by `PokerTable`).
