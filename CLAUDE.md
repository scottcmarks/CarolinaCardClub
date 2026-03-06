# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

This is a **Flutter + Dart** monorepo with three packages and a local Dart server:

```
carolina_card_club/
├── client/       # Flutter app (macOS primary target, also iOS/Android/web/Linux/Windows)
├── server/       # Dart HTTP/WebSocket server (shelf framework + SQLite)
├── shared/       # Dart package shared by client and server (constants, config)
└── db_connection/ # Flutter package: WebSocket connection provider for the client
```

The **server** runs locally (default port 5109) and the **client** connects to it via HTTP REST + WebSocket. The server holds the SQLite database (`CarolinaCardClub.db`) and the client is stateless — it fetches all data from the server.

## Running the App

**Start the server** (from `server/` directory):
```bash
cd server && dart run bin/carolina_card_club_server.dart
```

**Run the Flutter client** (from `client/` directory):
```bash
cd client && flutter run -d macos
```

**Run on a specific device:**
```bash
cd client && flutter run -d <device-id>
flutter devices  # list available devices
```

**Run Flutter tests:**
```bash
cd client && flutter test
cd client && flutter test test/widget_test.dart  # single test file
```

**Run server tests:**
```bash
cd server && dart test
```

**Get dependencies:**
```bash
cd client && flutter pub get
cd server && dart pub get
```

## Key Architecture Details

### Client State Management
The client uses `provider` for state. The provider chain in `main.dart`:
1. `AppSettingsProvider` — persists user settings (server IP/port, theme) via `shared_preferences`
2. `TimeProvider` — maintains the game clock with a server-synchronized offset
3. `DbConnectionProvider` (from `db_connection` package) — manages the WebSocket connection
4. `ApiProvider` — all REST API calls and data state (players, sessions, tables)

`ApiProvider` listens to WebSocket broadcasts from the server. When the server mutates state, it broadcasts `state_changed`, causing the client to call `reloadAll()`.

### Server Communication
- **REST** (HTTP via `http` package): All mutations and data fetches use REST endpoints on `http://<serverIp>:<serverPort>`
- **WebSocket** (`/ws`): Server-to-client push only. Server sends `state_changed` events after mutations; client also receives `clock_offset` broadcasts
- **Auth**: All REST requests require `x-api-key` header matching `Shared.defaultLocalApiKey`. WebSocket skips auth.

### Database
SQLite file (`CarolinaCardClub.db`) sits in the server's working directory. The server uses `sqflite_common_ffi`. Key tables: `Player`, `Session`, `Payment`, `PokerTable`, `System_State`. The server also queries two SQLite views: `Player_Selection_List` and `Session_Panel_List`.

### Remote Backup
The server can push/pull the DB file to `carolinacardclub.com/db_handler.php` via `POST /maintenance/backup` and `POST /maintenance/restore`.

### Shared Package
`shared/lib/src/constants.dart` (`Shared` class) contains all configuration constants used by both client and server: API keys, default port (5109), DB filename, remote server URL, session/warning thresholds.

### Clock Offset
`TimeProvider` maintains a `Duration offset` applied to `DateTime.now()` to synchronize the game clock with the server. The offset is set by the admin via `POST /state/clock-offset` and broadcast to all connected clients via WebSocket.

## UI Structure

`HomePage` has a two-column layout:
- Left (350px): `PlayerPanel` — scrollable list of players for selection
- Right (expanded): `SessionPanel` — active/historical sessions

Additional pages: `SettingsPage`, `SeatingFlowPage`, `TableViewPage`, `TabletTablePage`
