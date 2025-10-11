#!/usr/bin/env python3
import sqlite3
import json
import pyperclip

con = sqlite3.connect("CarolinaCardClub.db")

res = con.cursor().execute("SELECT * from Email_List;")

row = res.fetchone()
email_addresses=''
n_email_addresses=0
while row is not None:
    (Name, EmailAddresses, PhoneNumbers, Super_Bowl, Flag) = row
    if '[]'!=PhoneNumbers and Flag is None:
        try:
            for EmailAddress in json.loads(EmailAddresses):
                email_addresses+=( Name + " <" + EmailAddress + ">\n" )
                n_email_addresses += 1
        except json.JSONDecodeError:
            print("Error: Invalid JSON string provided for email addresses.")
    row= res.fetchone()

con.close()

pyperclip.copy(email_addresses)
print("Copied " + str(n_email_addresses) + " email addresses to clipboard.")
