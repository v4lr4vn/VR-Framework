# Booking at the station

Officers can sentence a suspect straight from the police station. No court case is needed. It is the quick route for arrests that end in the holding cells.

## How an officer books someone

1. Be on duty and inside a booking area (Mission Row by default) with the suspect standing next to you.
2. Look at the suspect with the third eye and choose **Book suspect**, or type `/book` (closest person) or `/book <id>`.
3. Pick the charges from the penal code. Choose a charge again to add more of the same, up to the limit.
4. Continue. Say whether they pleaded guilty (it lowers the maximum sentence) and add notes if you want.
5. Set the months and the fine. The charges decide the maximum, and the same discretion rules as the MDT decide the minimum.
6. Confirm.

## What happens

- An **arrest report** called *Booking: Name* is written in the MDT with the officer as author and the suspect marked as sentenced.
- The sentence is added to the suspect's record, and the fine is taken from their bank account (part-payment rules from `Config.Sentencing`).
- If the sentence has jail time, the suspect is sent to prison straight away and shows up on the MDT **Prison** tab.
- Everything is logged in the MDT audit trail as `booking`.

The officer needs the MDT permissions **Apply fines and jail time** and **Write reports**. Both can be set per rank in the MDT.

## Booking areas

`config/booking.lua` lists the areas where booking works. Admins can add more in game: stand in the middle of the station and type `/bookingarea add <radius> <name>`. `/bookingarea list` shows them and `/bookingarea remove <id>` deletes one.

## Settings

| Setting | What it does |
|---|---|
| `enabled` | Turns booking off |
| `command` | The chat command (`book`) |
| `range` | How close the suspect must be to the officer |
| `requireRestrained` | `true` means the suspect must be handcuffed |
| `interactDistance` | Third-eye distance |
| `areas` | Built-in booking areas |

For other scripts: client export `BookSuspect(serverId)` opens the same menu; server export `IsBookingArea(x, y, z)`.
