#!/usr/bin/env python3
"""
Unattended sender for the weekly Carolina Card Club email — Option A.

Runs locally (cron) at the target send time, e.g. Tuesday 2:30 PM. It ONLY does
anything if the sentinel file exists:

    ~/carolina_card_club/send_email_ok

When the sentinel is present it finds TODAY's "POKER TONIGHT ... <today> ..." draft
(the one the Cowork workflow built and you reviewed) and sends it as-is via the
Gmail API, then deletes the sentinel. If the sentinel is absent it does nothing,
so the default behaviour stays "leave a draft for manual review/send".

Safety rules:
  * No sentinel            -> exit 0, do nothing.
  * Zero matching drafts   -> do NOT send, leave sentinel, exit 2.
  * More than one match    -> do NOT send (ambiguous), leave sentinel, exit 2.
  * Send fails             -> leave sentinel, exit 1.
  * Exactly one match sent -> delete sentinel, exit 0.
The sentinel is deleted ONLY after a confirmed successful send, so a failure
leaves things in a state you can notice and retry.

One-time setup (you do this — it needs your Google login, which the script can't
and shouldn't do for you): see weekly_poker_email/README.md "Auto-send".
Requires:  pip install google-api-python-client google-auth google-auth-oauthlib
Credentials:
    CCC_GMAIL_CREDENTIALS  (default ~/.config/ccc/credentials.json) — OAuth client
    CCC_GMAIL_TOKEN        (default ~/.config/ccc/token.json)       — minted on first run
Scope: gmail.modify (lets us list drafts and send them).
"""
import os
import sys
from datetime import datetime

SCOPES = ["https://www.googleapis.com/auth/gmail.modify"]
SENTINEL = os.path.expanduser(os.environ.get("CCC_SEND_SENTINEL", "~/carolina_card_club/send_email_ok"))
CRED_PATH = os.path.expanduser(os.environ.get("CCC_GMAIL_CREDENTIALS", "~/.config/ccc/credentials.json"))
TOKEN_PATH = os.path.expanduser(os.environ.get("CCC_GMAIL_TOKEN", "~/.config/ccc/token.json"))


def log(msg):
    print(f"[{datetime.now().isoformat(timespec='seconds')}] send_if_armed: {msg}", flush=True)


def today_date_string():
    # Matches the subject format the workflow uses, e.g. "June 2, 2026".
    try:
        return datetime.now().strftime("%B %-d, %Y")   # Linux/macOS
    except ValueError:
        return datetime.now().strftime("%B %#d, %Y")   # Windows fallback


def get_service():
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from google_auth_oauthlib.flow import InstalledAppFlow
    from googleapiclient.discovery import build

    creds = None
    if os.path.exists(TOKEN_PATH):
        creds = Credentials.from_authorized_user_file(TOKEN_PATH, SCOPES)
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not os.path.exists(CRED_PATH):
                log(f"ERROR: OAuth client file not found: {CRED_PATH}. See README 'Auto-send'.")
                sys.exit(3)
            flow = InstalledAppFlow.from_client_secrets_file(CRED_PATH, SCOPES)
            creds = flow.run_local_server(port=0)
        os.makedirs(os.path.dirname(TOKEN_PATH), exist_ok=True)
        with open(TOKEN_PATH, "w") as fh:
            fh.write(creds.to_json())
    return build("gmail", "v1", credentials=creds)


def find_todays_draft(service, date_str):
    """Return the single matching draft id, or None / raise on ambiguity."""
    resp = service.users().drafts().list(
        userId="me", q='subject:"POKER TONIGHT"', maxResults=50
    ).execute()
    matches = []
    for d in resp.get("drafts", []):
        full = service.users().drafts().get(userId="me", id=d["id"], format="metadata").execute()
        headers = full.get("message", {}).get("payload", {}).get("headers", [])
        subject = next((h["value"] for h in headers if h["name"].lower() == "subject"), "")
        if "POKER TONIGHT" in subject and date_str in subject:
            matches.append((d["id"], subject))
    return matches


def main():
    if not os.path.exists(SENTINEL):
        log(f"sentinel not present ({SENTINEL}); nothing to do.")
        return 0

    date_str = today_date_string()
    log(f"sentinel present; looking for today's draft (subject contains '{date_str}').")

    service = get_service()
    matches = find_todays_draft(service, date_str)

    if len(matches) == 0:
        log(f"NO draft found matching POKER TONIGHT + '{date_str}'. Not sending. Leaving sentinel.")
        return 2
    if len(matches) > 1:
        log(f"AMBIGUOUS: {len(matches)} drafts match: {[s for _, s in matches]}. Not sending. Leaving sentinel.")
        return 2

    draft_id, subject = matches[0]
    log(f"sending draft: {subject!r}")
    try:
        sent = service.users().drafts().send(userId="me", body={"id": draft_id}).execute()
    except Exception as e:
        log(f"SEND FAILED: {e}. Leaving sentinel for retry.")
        return 1

    log(f"sent OK (message id {sent.get('id')}). Deleting sentinel.")
    try:
        os.remove(SENTINEL)
    except OSError as e:
        log(f"WARNING: send succeeded but could not delete sentinel {SENTINEL}: {e}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
