#!/usr/bin/env python3
import json
import os
import sqlite3
import sys
import urllib.parse
import urllib.request

import pyperclip

# Prefer the remote (canonical) database via db_handler.php's whitelisted,
# read-only 'email_list' query. If the remote is unreachable, fall back to the
# local server copy. If neither works, die.
#
# Same endpoint/credentials as bin/push_db / bin/pull_db / bin/deploy_db_handler.
URL = "https://carolinacardclub.com/db_handler.php"
API_KEY = "31221da269c89d6e770cd96ad259433dffedd1f75250597cff4114144086129797bf09ab6fff19234e9674d7e48e428cd8aeb8a5a23a36abcd705acae8d1c030"
REQUEST_TIMEOUT = 8  # seconds — fail fast to the local fallback if remote is down

# The local DB lives next to this script in server/.
LOCAL_DB = os.path.join(os.path.dirname(os.path.abspath(__file__)), "CarolinaCardClub.db")

# Spoof Chrome on Windows to bypass ModSecurity (matches push_db/pull_db).
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                  "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "en-US,en;q=0.5",
    "Content-Type": "application/x-www-form-urlencoded",
}


def fetch_remote_rows():
    """Return Email_List rows (list of dicts) from the remote server, or raise."""
    body = urllib.parse.urlencode({
        "apiKey": API_KEY,
        "action": "query",
        "query": "email_list",
    }).encode()
    req = urllib.request.Request(URL, data=body, headers=HEADERS, method="POST")
    with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
        payload = resp.read().decode()
    rows = json.loads(payload)
    if isinstance(rows, dict) and "error" in rows:
        raise RuntimeError("server error: " + rows["error"])
    if not isinstance(rows, list):
        raise RuntimeError("unexpected response shape from server")
    return rows


def fetch_local_rows():
    """Return Email_List rows (list of dicts) from the local DB, or raise."""
    if not os.path.exists(LOCAL_DB) or os.path.getsize(LOCAL_DB) == 0:
        raise RuntimeError("local DB missing or empty: " + LOCAL_DB)
    con = sqlite3.connect(LOCAL_DB)
    try:
        con.row_factory = sqlite3.Row
        cur = con.execute("SELECT * FROM Email_List")
        return [dict(r) for r in cur.fetchall()]
    finally:
        con.close()


# --- choose a source: remote first, then local, else die ---
try:
    rows = fetch_remote_rows()
    source = "remote"
except Exception as remote_err:
    print("email_list: remote DB unreachable (%s); trying local copy..." % remote_err,
          file=sys.stderr)
    try:
        rows = fetch_local_rows()
        source = "local"
        print("email_list: using LOCAL database %s (may be stale)." % LOCAL_DB,
              file=sys.stderr)
    except Exception as local_err:
        sys.exit("email_list: no database reachable — remote (%s) and local (%s) both failed."
                 % (remote_err, local_err))

# --- build the list (identical logic regardless of source) ---
email_addresses = ''
n_email_addresses = 0
for row in rows:
    Name = row["Name"]
    EmailAddresses = row["EmailAddresses"]
    PhoneNumbers = row["PhoneNumbers"]
    Flag = row["Flag"]
    if PhoneNumbers != '[]' and Flag is None:
        try:
            for EmailAddress in json.loads(EmailAddresses):
                email_addresses += (Name + " <" + EmailAddress + ">\n")
                n_email_addresses += 1
        except json.JSONDecodeError:
            print("Error: Invalid JSON string provided for email addresses.")

pyperclip.copy(email_addresses)
print("Copied " + str(n_email_addresses) + " email addresses to clipboard from " + source + " db.")
