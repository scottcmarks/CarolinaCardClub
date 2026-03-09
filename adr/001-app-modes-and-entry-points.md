# ADR 001 — App Modes and Entry Points

**Date:** 2026-03-09
**Status:** Decided

---

## Context

The current client is the `admin` app. Two further modes are planned:
`floor` (table change requests, waiting list) and `tablet` (per-table
interface). All three share the same domain model, server communication
layer, and most UI components.

The question was: one executable with a CLI flag (`--admin`, `--floor`,
`--table 3`), three separate cloned repos, or something else?

A config file refactor (to move API keys and server settings out of
`shared/`) is planned imminently and changes the tradeoffs.

---

## Decision

**Multiple Flutter entry points in a single package, combined with a config
file for runtime parameters.**

Concretely:

```
client/lib/
  main_admin.dart    ← void main() => runApp(App(mode: Mode.admin))
  main_floor.dart    ← void main() => runApp(App(mode: Mode.floor))
  main_tablet.dart   ← void main() => runApp(App(mode: Mode.tablet))
```

Built with:
```bash
flutter build macos -t lib/main_admin.dart
flutter build macos -t lib/main_floor.dart
flutter build macos -t lib/main_tablet.dart
```

The **mode** (admin / floor / tablet) is baked into the entry point — it is
structural, not environmental, so it does not belong in the config file.

The **config file** carries runtime parameters that vary per deployment:
API keys, server IP/port, table number (for tablet mode). The config file
refactor should happen first, independently of the entry point split.

---

## Code structure

Shared code lives in `client/lib/core/`. Mode-specific shells compose from
it:

```
client/lib/
  core/              ← data models, API, WebSocket, shared widgets
  shells/
    admin_shell.dart
    floor_shell.dart
    tablet_shell.dart
  main_admin.dart
  main_floor.dart
  main_tablet.dart
```

**Rule:** Mode-specific behaviour belongs in the shells. Do not add
`if (mode == Mode.admin)` conditionals inside `core/` components.

---

## Rejected alternatives

**Single executable with CLI flag (`--admin`, `--floor`, `--table 3`)**
Workable, but requires launcher scripts or terminal invocation on each
device. The config file approach achieves the same runtime flexibility
without flags, and three distinct `.app` bundles are harder to confuse
in deployment.

**Three separate cloned repositories**
Ruled out immediately — duplicates all shared code, creates three places
to fix every bug.

---

## Consequences

- The config file refactor is a prerequisite and should be done first.
- `main.dart` becomes `main_admin.dart` (or is kept as `main.dart` for
  the admin build and the others are added alongside it).
- CI/build scripts will need to build three targets.
- The `Planned App Modes` section of `CLAUDE.md` reflects this decision.
