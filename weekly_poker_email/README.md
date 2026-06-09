# Weekly Poker Email — automated workflow

Replaces the manual Tuesday routine (run `email_list`, open Gmail, forward last
week's email, scrub the "Fwd:" cruft, fix the subject date, paste the BCC list)
with a two-piece hybrid that ends at a ready-to-send draft you review and send.

## Why hybrid?

The two things this task needs live in two different places:

- **The live recipient list** is in `server/CarolinaCardClub.db`, which is
  `.gitignore`d. Cowork's file layer hides gitignored files, so the Cowork agent
  **cannot** read the live DB. Only your Mac can.
- **Authenticated Gmail access** lives in Cowork (the connected Gmail account).
  A standalone local script would need its own Google OAuth setup.

So: a tiny **local step** exports the list to a file Cowork *can* see, and the
**Cowork step** does the Gmail draft. No OAuth required.

### Why not just have Cowork read the data directly?

Every direct route was tried; all are blocked by the Cowork sandbox boundary:

- **Local DB file** — hidden by the gitignore filter (even after un-ignoring +
  re-mounting, the sandbox didn't re-scan; submodule metadata lives outside the mount).
- **Remote whole-DB pull** (`db_handler.php?apiKey=...`) — the sandbox's outbound
  network is an allowlist (pypi/github work; everything else gets a 403 at the proxy),
  and `web_fetch` can't carry a binary SQLite file.
- **Local REST endpoints** (`/players/selection`, etc.) — those bind to
  `127.0.0.1:5109` on your Mac, unreachable from the sandbox, and there's no email route.

The block is at the sandbox boundary, not at any one source, so the data must be
handed in from outside (cron / Claude Code / the app). That outside step is small.

```
  ┌─ on your Mac ──────────────┐      ┌─ in Cowork ──────────────────────────┐
  │ bin/export_recipients      │      │ INVOCATION.md prompt                  │
  │   reads live DB (Email_List)│ ──▶ │   reads weekly_recipients.json        │
  │   writes weekly_recipients  │ json │   finds last week's sent email        │
  │   .json (~150 addresses)    │ file │   creates today's draft (subj+body+bcc)│
  └────────────────────────────┘      │   flags stale dates → you review/send │
                                       └───────────────────────────────────────┘
```

## Files

| File | Where it runs | What it does |
|---|---|---|
| `server/export_recipients.py` | Mac | Reads the `Email_List` view, writes `weekly_recipients.json`. Same inclusion rule as the old `email_list_to_clipboard.py` (phone on file **and** `Flag IS NULL`). `--remote` pulls the authoritative DB from carolinacardclub.com first (recommended for cron — no dependency on the local cache being current). |
| `bin/export_recipients` | Mac | Wrapper: `cd server`, activate venv, run the exporter. Cron-friendly. Pass `--remote` to use the authoritative server copy. |
| `server/weekly_recipients.json` | (output) | The handoff file Cowork reads. **Must stay non-gitignored** or Cowork can't see it. |
| `weekly_poker_email/INVOCATION.md` | Cowork | The "magic" prompt that builds the draft (incl. date-stale scan + tournament-block refresh from Don Levine's Inbox). |
| `server/send_if_armed.py` / `bin/send_if_armed` | Mac | Optional unattended sender. If `~/carolina_card_club/send_email_ok` exists, sends today's reviewed draft via the Gmail API and deletes the sentinel. Does nothing if the sentinel is absent. |

## One-time setup

1. Confirm the exporter works against your live DB:
   ```bash
   ~/carolina_card_club/bin/export_recipients
   # -> "Exported ~150 email addresses -> .../server/weekly_recipients.json"
   ```
2. Make sure `weekly_recipients.json` is **not** gitignored. (The committed
   `*.sql` dump already contains this PII, so tracking the JSON changes nothing
   privacy-wise, and it's required for Cowork visibility.)

## Weekly use (manual, while shaking out bumps)

1. On your Mac: `~/carolina_card_club/bin/export_recipients`
2. In Cowork: paste the prompt from `INVOCATION.md` (or just say
   "run the weekly poker email").
3. Review the draft Gmail creates — especially anything it flags as date-stale
   (tournament date, host line) — then hit **Send**.

## Cron it (once you trust it)

Two schedulers, because the two pieces run in two places.

**A. Local export — real crontab on your Mac.** Refresh the list every Tuesday at
noon, an hour before the draft is built:
```cron
# m h dom mon dow   (dow 2 = Tuesday)
0 12 * * 2  /Users/scott/carolina_card_club/bin/export_recipients --remote >> /tmp/ccc_export.log 2>&1
```

**One-click install:** `bin/install_cron` installs/updates both local jobs (this
noon export and the 2:30 sender below) idempotently. `--dry-run` previews,
`--remove` uninstalls.

**B. Draft creation — Cowork scheduled task.** INSTALLED: task `weekly-poker-email`
runs every Tuesday at 1:00 PM (see the "Scheduled" section in Cowork's sidebar; the
prompt mirrors `INVOCATION.md`). It stops at a draft and notifies when ready.
Caveat: Cowork scheduled tasks only run while the Cowork app is open (a missed run
fires on next launch). Click "Run now" on it once to pre-approve its Gmail/folder
permissions so future runs don't pause waiting for approval.

**C. (Optional) Unattended send — local crontab at 2:30 PM.** See "Auto-send" below.
```cron
30 14 * * 2  /Users/scott/carolina_card_club/bin/send_if_armed >> /tmp/ccc_send.log 2>&1
```

> Keep the final **send** manual until you've watched it produce a correct draft
> for a few weeks. The body is carried over verbatim, so a stale tournament date
> or host name will otherwise go out to ~150 people.

## Auto-send (optional, sentinel-gated)

`send_if_armed` lets you opt in to an unattended 2:30 PM send on a per-week basis,
without giving up the safety net the rest of the time.

**How it behaves**

- **No `~/carolina_card_club/send_email_ok` file** → it does nothing; you review the
  draft and send manually. This is the default.
- **Sentinel present** → at 2:30 PM it finds *today's* `POKER TONIGHT … <today> …`
  draft, sends it as-is via the Gmail API, and deletes the sentinel.
- It will **refuse to send** (and leave the sentinel in place, logging loudly) if it
  finds zero or more than one matching draft, or if the send errors — so a problem
  fails safe rather than firing the wrong thing.

**Arming it for a given week:** create the flag any time before 2:30 PM Tuesday:
```bash
touch ~/carolina_card_club/send_email_ok
```
(Do this only once you trust the draft the workflow produces — it sends to ~150
people with no further review.)

**One-time Gmail API setup (you must do this — it needs your Google login):**

1. `pip install google-api-python-client google-auth google-auth-oauthlib`
   (into the same `server/venv` the other scripts use).
2. In Google Cloud Console: enable the **Gmail API**, create an **OAuth client ID**
   of type **Desktop app**, and download its JSON.
3. Save it as `~/.config/ccc/credentials.json` (or set `CCC_GMAIL_CREDENTIALS`).
4. Run `bin/send_if_armed` once *with the sentinel present*; it opens a browser for
   you to authorize the **gmail.modify** scope, then stores the token at
   `~/.config/ccc/token.json` (override with `CCC_GMAIL_TOKEN`). Subsequent runs are
   headless. Keep `~/.config/ccc/` out of any repo — it holds your credentials.

> Why this runs locally and not in Cowork: the Cowork Gmail connector can only create
> drafts — it has no send (and Gmail's "Schedule send" isn't in the API). The sentinel
> file is on your Mac too. So the privileged send is a small local cron; Cowork still
> does all the assembly.

## Known bumps / gotchas

- **Gitignore visibility.** Anything gitignored is invisible to Cowork (verified:
  the live `.db` can't be read from here). The handoff JSON must stay tracked.
- **Stale list.** If `weekly_recipients.json` is older than 7 days, the prompt
  tells the agent to stop and ask you to re-run the exporter. A BCC count near 0
  or far from ~150 is the tell that something's off.
- **Stale body content.** The email body is reproduced verbatim from last week
  (matching the old "forward" behavior). The tournament `Date:` line and
  "This week's game is hosted by ..." do not auto-update — the prompt flags them
  for you, but you decide the new values at review time.
- **Subject prefixes.** Seasonal subject prefixes (e.g. "PIZZA NIGHT POKER:") are
  dropped by default; the agent only carries the standard "POKER TONIGHT:" form
  and swaps in today's date. Tell it otherwise if you want a prefix kept.
