Carolina Card House Objects
Copyright 2025 Scott Marks
All rights reserved

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
- Name
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

Logo
Carolina Card Club
Bottom bar
♠️♥️♦️♣️

Player sorting order
Players should be grouped by date of most recent play; within each group by category; within each category, alpha by nickname or name.

Session list:
Grouped by player, by player sorting order as above
Sorted by date if more than one within player
A players group of sessions only appears when the session fees add up to less than the sum of the player’s payments, in which case those sessions who fees add up less to the sum of the players payment’s do not appear
No sessions being ordered for consideration from oldest to newest so that only the most recent session or perhaps two actually appea
The most common case will be that a player is paid up, so that none of his sessions appear in the session list.

Player list, click action:
If the player has no sessions in the session list, ( see previous remark) then a new session started for him immediately using the session start clock limited to no earlier than 730
If a player has sessions in the session list, a pop-up asking if he wants to pay his overage appears, and his sessions in the session list are made visible, scrolling if necessary, and highlighted, as if just selected. This pop-up includes a text box initialize the value of his overage, in which this prepayment can be entered. There should be an OK button and a cancel button. OK means pay i.e. create a payment record in the amount entered in the text box for the player. This should cause recalculation, and if the amount is sufficient, should cause his previous sessions to disappear from the session list. this step can be repeated as necessary while there are still entries for this player in the session list. This step can be canceled with the cancel button.
In any event when the step is finished, the session is created for the player as in the discussion above, which probably oughta be right here.

Sessions list should have radio buttons to select sort/filter: just current session; sorted by session back into the past; grouped by player sorted by date desc.

————————————————

When a session is added it goes to the top of the list, which makes it awkward to switch back to all sessions look

Add new money needs to continue on to start new session. I lost starting up Peter.

Ending a session needs to cause the player card to be selected and if it now has a negative balance, pop up the payment dialog.  During this process, if the payment makes the player balance zero, the player should be unselected so all remaining sessions will show.

Why is the payment dialog off in its calculation of amount?  Not using the club session start as min time?

Definitely must get the db back out. I suppose we need two processes at least, a db server even if only on localhost, talking to the ui app.

Need to be able to add players/edit player info, even session or payment info sometimes.

Is it ever just running off the copy of the db in documents without copying?



Suppressing some irrelevant stuff:

```
.
├── client
│   ├── assets
│   │   ├── CarolinaCardClub.db
│   │   ├── CarolinaCardClub.db.schema.sql
│   │   ├── CarolinaCardClub.db.sql
│   │   ├── CarolinaCardClub.sqbpro
│   │   └── CCCBanner.png
│   ├── lib
│   │   ├── main.dart
│   │   ├── models
│   │   │   ├── app_settings.dart
│   │   │   ├── payment.dart
│   │   │   ├── player_category.dart
│   │   │   ├── player_info.dart
│   │   │   ├── player_selection_item.dart
│   │   │   ├── player.dart
│   │   │   ├── rate_interval.dart
│   │   │   ├── rate.dart
│   │   │   ├── session_panel_item.dart
│   │   │   └── session.dart
│   │   ├── providers
│   │   │   ├── api_provider.dart
│   │   │   ├── app_settings_provider.dart
│   │   │   ├── session_filter_provider.dart
│   │   │   └── time_provider.dart
│   │   └── widgets
│   │       ├── carolina_card_club_app.dart
│   │       ├── main_split_view_page.dart
│   │       ├── player_panel.dart
│   │       ├── realtimeclock.dart
│   │       ├── session_panel.dart
│   │       └── settings_page.dart
│   └── test
│       └── widget_test.dart
├── db_connection
│   └── lib
│       ├── db_connection.dart
│       └── providers
│           └── db_connection_provider.dart
├── server
│   └── bin
│       └── carolina_card_club_server.dart
└── shared
    └── lib
        ├── shared.dart
        └── src
            └── constants.dart
```
