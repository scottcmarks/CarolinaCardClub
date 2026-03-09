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
