#!/usr/bin/env python3
"""
Export the weekly Carolina Card Club email recipients from the live database
to a JSON file that the Cowork "weekly poker email" workflow can read.

This is the headless replacement for the clipboard-based email_list_to_clipboard.py.
It applies the IDENTICAL inclusion rule:
    include a player only if PhoneNumbers != '[]'  AND  Flag IS NULL
and expands the JSON array of email addresses, one entry per address.

Output (default: weekly_recipients.json next to this script):
    {
      "generated_at": "<ISO-8601 local time>",
      "source_db": "<absolute path of the db read>",
      "count": <number of email addresses>,
      "emails": ["a@x.com", ...],                # flat list, for Gmail BCC
      "recipients": [{"name": "...", "email": "..."}, ...],
      "bcc_line": "Name <a@x.com>\nName <b@y.com>\n..."   # clipboard-style text
    }

IMPORTANT: keep weekly_recipients.json OUT of .gitignore. Cowork's file layer
hides gitignored files, so the workflow can only read it if it is visible.
(The committed *.sql dump already contains this PII, so tracking the JSON does
not change the repo's privacy posture.)

Usage:
    python3 export_recipients.py                       # live db -> weekly_recipients.json
    python3 export_recipients.py --db CarolinaCardClub.db.bak --out /tmp/test.json
    python3 export_recipients.py --clipboard           # also copy bcc_line to clipboard
"""
import argparse
import json
import os
import sqlite3
import sys
import tempfile
import urllib.request
from datetime import datetime

DEFAULT_DB = os.path.join(os.path.dirname(os.path.abspath(__file__)), "CarolinaCardClub.db")
DEFAULT_OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "weekly_recipients.json")

# The remote DB is the source of truth (the local server/CarolinaCardClub.db is a
# cache that bin/push_db uploads to it). With --remote we GET the authoritative copy
# straight from the handler. URL/key default to bin/push_db's values; override via
# CCC_DB_URL / CCC_DB_API_KEY env vars. NOTE: this only works where the network is
# unrestricted (your Mac) — the Cowork sandbox blocks outbound to this domain.
DEFAULT_REMOTE_URL = os.environ.get("CCC_DB_URL", "https://carolinacardclub.com/db_handler.php")
DEFAULT_API_KEY = os.environ.get(
    "CCC_DB_API_KEY",
    "31221da269c89d6e770cd96ad259433dffedd1f75250597cff4114144086129797bf09ab6fff19234e9674d7e48e428cd8aeb8a5a23a36abcd705acae8d1c030",
)


def fetch_remote_db(url, api_key):
    """Download the authoritative DB to a temp file and return its path."""
    req = urllib.request.Request(
        f"{url}?apiKey={api_key}",
        headers={
            # Spoof Chrome to get past the server's ModSecurity, same as bin/push_db.
            "User-Agent": ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                           "AppleWebKit/537.36 (KHTML, like Gecko) "
                           "Chrome/120.0.0.0 Safari/537.36"),
            "Accept": "application/octet-stream,*/*;q=0.8",
        },
    )
    fd, path = tempfile.mkstemp(suffix=".db", prefix="ccc_remote_")
    with urllib.request.urlopen(req, timeout=60) as resp, os.fdopen(fd, "wb") as out:
        out.write(resp.read())
    # Sanity-check it really is a SQLite file, not an error page.
    with open(path, "rb") as fh:
        if fh.read(16) != b"SQLite format 3\x00":
            os.unlink(path)
            raise RuntimeError("Remote did not return a SQLite database (bad key or ModSecurity block?)")
    return path


def build(db_path):
    con = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    try:
        rows = con.cursor().execute("SELECT * FROM Email_List;").fetchall()
    finally:
        con.close()

    recipients = []
    emails = []
    bcc_parts = []
    for row in rows:
        # View column order: Name, EmailAddresses, PhoneNumbers, Super_Bowl, Flag
        Name, EmailAddresses, PhoneNumbers, Super_Bowl, Flag = row
        if PhoneNumbers == "[]" or Flag is not None:
            continue
        try:
            addresses = json.loads(EmailAddresses)
        except json.JSONDecodeError:
            print(f"WARNING: invalid JSON email field for {Name!r}; skipping", file=sys.stderr)
            continue
        for addr in addresses:
            recipients.append({"name": Name, "email": addr})
            emails.append(addr)
            bcc_parts.append(f"{Name} <{addr}>")

    return {
        "generated_at": datetime.now().astimezone().isoformat(timespec="seconds"),
        "source_db": os.path.abspath(db_path),
        "count": len(emails),
        "emails": emails,
        "recipients": recipients,
        "bcc_line": "\n".join(bcc_parts) + ("\n" if bcc_parts else ""),
    }


def main():
    ap = argparse.ArgumentParser(description="Export weekly CCC email recipients to JSON.")
    ap.add_argument("--db", default=DEFAULT_DB, help=f"SQLite db path (default: {DEFAULT_DB})")
    ap.add_argument("--out", default=DEFAULT_OUT, help=f"Output JSON path (default: {DEFAULT_OUT})")
    ap.add_argument("--remote", action="store_true",
                    help="Pull the authoritative DB from the remote handler instead of reading --db. "
                         "Only works where outbound network is allowed (your Mac, not the Cowork sandbox).")
    ap.add_argument("--remote-url", default=DEFAULT_REMOTE_URL, help=argparse.SUPPRESS)
    ap.add_argument("--clipboard", action="store_true",
                    help="Also copy the Name <email> list to the clipboard (needs pyperclip).")
    args = ap.parse_args()

    tmp_db = None
    try:
        if args.remote:
            print(f"Fetching authoritative DB from {args.remote_url} ...")
            tmp_db = fetch_remote_db(args.remote_url, DEFAULT_API_KEY)
            db_path = tmp_db
        else:
            if not os.path.exists(args.db):
                print(f"ERROR: database not found: {args.db}", file=sys.stderr)
                sys.exit(1)
            db_path = args.db

        data = build(db_path)
    finally:
        if tmp_db and os.path.exists(tmp_db):
            os.unlink(tmp_db)

    with open(args.out, "w") as fh:
        json.dump(data, fh, indent=2)

    print(f"Exported {data['count']} email addresses "
          f"({len(data['recipients'])} player rows) -> {args.out}")

    if args.clipboard:
        try:
            import pyperclip
            pyperclip.copy(data["bcc_line"])
            print("Also copied Name <email> list to clipboard.")
        except Exception as e:  # pragma: no cover
            print(f"Clipboard copy skipped: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
