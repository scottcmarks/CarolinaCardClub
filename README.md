# CarolinaCardClub
Database and access thereto  
Copyright 2025 Scott Marks  
All rights reserved

## Carolina Card House Objects

A session has
- A session ID
- A player ID
- A start time
- (Volatile) Maybe a stop time
- (Derived) Some payment IDs
- (Derived) Prepaid time remaining

A payment has
- A payment ID
- An amount
- A session ID

A player has
- A player ID
- First Name
- Last Name
- Nickname (defaults to Name)
- Email address
- Phone number
- (Volatile) Prepaid balance
- (Derived) Some session IDs
- (Derived) maybe current session ID
- (Derived) finished sessions unpaid balance
- (Derived, volatile) maybe current session prepaid time remaining

Player ID list is
- Some player IDs

Player list is
- (Derived) some (Name, Email address, Phone Number) for each player


## Toolchain
[DB Browser for SQLite](https://sqlitebrowser.org/dl/)
