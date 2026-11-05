# vr-cityhall

City Hall for ValRavn. Three services at one desk: replace a lost ID or licence, the Job Centre, and business licences.

## What players can do

Walk up to the clerk at City Hall and use the third eye. One window with three tabs opens.

- **Replace documents.** Get a new ID card, driver's licence or firearms licence for a fee. Driver's and firearms licences are only replaced for people who already hold the licence (passed the test, got the permit). You cannot replace a card you still carry, and there is a short wait between replacements.
- **Job Centre.** Browse the civilian jobs, see the starting rank and pay, take one, or leave one. Jobs you hold stay on your job menu (`vr-multijob`) up to the job limit.
- **Business licences.** Apply for a licence of a type, with a business name. Each lasts 30 days. Renew in the last 7 days, or after it runs out. Replace a lost certificate, or surrender the licence. Admins can revoke it.

Fees come out of the bank first, then cash, and are paid into a society account (`Config.Society`, `government` by default).

## Business licences

| Rule | Default |
|---|---|
| Licences one person can hold at once | 3 |
| Types | Retail, Food and drink, Trades and repairs, Vehicle sales, Entertainment, Professional services |
| Duration | 30 days (real time) |
| Renew window | Last 7 days, or any time after it has expired |
| Names | 3 to 32 characters, one active licence per name (case, spacing and punctuation ignored) |
| Certificate item | `business_license`, with number, business and type in its details |
| Surrender refund | 0% (`Config.Business.refundPercent`) |

A licence number looks like `LS-000123`. Expired licences free their business name. Players are reminded when they log in if a licence has expired or runs out within three days.

When a person holds at least one active licence, the `business` licence flag is set on their character, so other scripts can read it through vr-core's `licences` data. It is cleared when the last one ends.

## Admin

`/bizlicence check <number>`, `/bizlicence who <id>`, `/bizlicence revoke <number> [note]`, `/bizlicence reinstate <number>`, `/bizlicence grant <id> <type> <business name>`. Admins only. `grant` is free and ignores the per-player limit.

## For other scripts

Server exports:

- `HasBusinessLicence(srcOrCitizenId, type?)`: true if the character holds an active licence, optionally of one type.
- `GetBusinessLicences(srcOrCitizenId)`: list of licences (number, name, type, status, issued, expires).
- `GetLicenceByNumber(number)`
- `IssueBusinessLicence(src, type, name, days?)`: free, ignores the limit.
- `RevokeBusinessLicence(number, note?)`, `ReinstateBusinessLicence(number)`

Server events: `vr-cityhall:server:licenceIssued` (src, citizenid, number, type, name) and `vr-cityhall:server:licenceEnded` (citizenid, number, 'surrendered' or 'revoked').

The table is `vr_business_licences`, created on start. On vr-core it is registered as a character table, so a deleted character's licences go with them.

## Settings

All in `config.lua`:

- `Config.Desks`: where the clerk stands (add more rows for more halls), the model and the blip.
- `Config.Documents`: which items can be replaced, their fees, the licence each one needs, the wait between replacements.
- `Config.JobCentre`: the jobs on offer (job name, grade, icon, description), the job limit, whether people can quit, and the job people fall back to.
- `Config.Business`: types, fees, duration, limits, the name rules, the certificate item and the refund.

Jobs on the list that do not exist in your framework are left out, so you can list jobs before you add them.

## Setup notes

- The desk position is a first guess at the Integrity Way hall. Stand where you want the clerk, copy your coordinates and heading into `Config.Desks`.
- Add `business_license` to your inventory items if you do not use vr-inventory (it ships with this release). Without it licences still work and no certificate is handed out.
- With `vr-idcard` running, replacement cards are made by it. Without it, a plain card item with the character's name and citizen id is added.
- With `vr-multijob` running, taking a job at the Job Centre adds it to the job menu and quitting removes it.

## Works with

vr-core, Qbox, QBCore, ESX and ox_core through vr-bridge. Needs vr-lib and vr-bridge.
