# Weekly Poker Email — Cowork invocation

This is the "one magic invocation." Paste the prompt below into Cowork (or set it
as a weekly scheduled task). It assumes `server/weekly_recipients.json` is current
— keep it fresh by running `bin/export_recipients` locally (see README, cron step).

The agent stops at a ready-to-send **draft**; Scott reviews and sends.

---

## PROMPT (copy everything between the lines)

```
Create this week's Carolina Card Club "POKER TONIGHT" email as a Gmail DRAFT. Do not send it.

Steps:
1. Read server/weekly_recipients.json in the carolina_card_club folder. Use its
   "emails" array as the BCC list. If the file is missing or its "generated_at" is
   older than 7 days, STOP and tell me to run `bin/export_recipients` first.

2. Establish "now" = the target send moment: THIS Tuesday at 2:30 PM local time
   (normally today). Every date check below is relative to that moment.

3. In Gmail, find the most recent message I SENT on the "* Carolina Card Club"
   label whose subject contains "POKER TONIGHT" (search:
   label:"* Carolina Card Club" from:me in:sent "POKER TONIGHT", newest first).
   That is last week's email. Read its body. This is your working copy of the body
   — reproduce it verbatim (same text, links, formatting), with NO quoted/forwarded
   history and no "Fwd:" prefix. Do NOT create the draft yet; assemble the final
   body first (steps 4–5), then create it once in step 7.

4. REFRESH THE TOURNAMENT BLOCK from Don Levine's Inbox. The body has an embedded
   tournament announcement (lines like "Date: <day> ... Time: ... Location: Five
   Oaks ... Buy In ... Future Dates: ..."). Search my Inbox for Don's latest version:
       from:dlevi363@gmail.com in:inbox  (also try from:"Don Levine"), newest first,
   looking for a message whose content matches that tournament announcement.
   - If you find one whose dates are LATER than the embedded block's, replace the
     embedded block in the body with the corresponding text from Don's email.
   - Match the surrounding formatting as closely as you can.
   - If you find nothing newer, leave the block as-is and flag it (step 6).
   (This substitution is fine — I review before anything goes out.)

5. SUBJECT: take last week's subject and replace the date with the target Tuesday's
   date, keeping the format exactly:
       POKER TONIGHT: <Weekday>, <Month> <D>, <Year> at 7:00 pm at Five Oaks
   Drop any seasonal/extra prefix (e.g. "PIZZA NIGHT POKER:") unless I say otherwise.

6. DATE-STALE SCAN: scan the FINAL assembled body for any calendar date that falls
   strictly BEFORE "now" (the target Tuesday 2:30 PM). Examples to watch: the
   tournament "Date:" line, items in "Future Dates:", and "This week's game is hosted
   by ...". List every past-dated item you find. After the step-4 refresh there
   should ideally be none; report any that remain. Do NOT invent replacement values.

7. Create the Gmail draft now, once, with the finalized body:
       To:  scott.c.marks@gmail.com   (real recipients go in BCC, like undisclosed-recipients)
       Bcc: the "emails" array from weekly_recipients.json
       Subject: from step 5
       Body: the assembled body from steps 3–4 (provide both HTML and plain-text)

8. Report back: the final subject, the BCC count, what tournament text you swapped
   (old dates → new dates, or "no newer version found"), and any past-dated items
   still remaining. Leave it as a draft. I'll review and send.

   (Unattended send when ~/carolina_card_club/send_email_ok is present is handled by
   a SEPARATE local step at 2:30 PM — see README "Auto-send" — because the Gmail
   connector here cannot send, only draft.)
```

---

## Notes for whoever runs this

- BCC count should be ~150. If it's wildly off (e.g. 0 or 5), `weekly_recipients.json`
  is probably stale or empty — re-run `bin/export_recipients`.
- The body is intentionally carried over verbatim each week (that's what the manual
  "forward" did). The agent only changes the subject date; everything else is yours
  to tweak at review time.
- Recipient rule (mirrors the old `email_list`): a player is included only if they
  have at least one phone number on file **and** their `Flag` is NULL.
