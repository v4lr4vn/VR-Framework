# vr-banking

Banking for ValRavn. Built on vr-core money and society accounts, so every script that pays wages,
fines or invoices keeps working and shows up in the bank history. No outside calls.

## Accounts

- **Personal**: the player's vr-core `bank` balance with an account number.
- **Savings**: pays `Config.Savings.ratePercent` every `periodHours` on balances over `minBalance`, capped at `maxInterestBalance`.
- **Shared**: owner plus members. Members deposit and see activity. Managers can also withdraw, send money and get a card.
- **Business / organisation**: the vr-core society balance for a job or gang. Bosses get access, or grades set in `Config.Society.minGrade`.

Branches are the teller desks in `Config.Branches`. Use the eye on the desk.

## Cards and ATMs

Order a card at a branch (fee `Config.Cards.fee`) and pick a 4-digit PIN. The card is a `bank_card` item.
ATMs need the card in your pockets and the PIN. Anyone holding the card who knows the PIN can use it, so a stolen card is a real risk.
Three wrong PINs lock the card for `lockMinutes` (or the machine keeps it with `retainOnLock`).
Cards can be frozen, unlocked, given a new PIN or cancelled at a branch. PINs are stored as salted SHA-256 hashes.

## Loans and credit

Everyone starts at `Config.Credit.start`. Each tier sets the most you can borrow and the rate.
Interest for a loan is `amount x rate% x payments / 12`. A vehicle from `player_vehicles` can be pledged to raise the limit and lower the rate.
Installments come out of the personal account every `intervalHours`, online or offline.
A missed payment adds a late fee and lowers the score. After `defaultAfterMissed` misses in a row the loan defaults and goes to collections.

## Debt collection job

Add players to the `debtcollector` job. They clock in at any branch, then:

- open the **Collections board** at a branch or with `/collections`
- **claim** a case so nobody else works it for `claimMinutes`
- **trace** a vehicle to get a rough waypoint if it is out in the city
- **repossess** a case vehicle with the eye (nobody in the driver seat). The vehicle is held by the bank and a repo fee is added to the debt
- **collect debt** in person with the eye on the debtor, who can pay from bank or cash

Collectors earn `collectorRepoPay` per repossession and `commissionPercent` of money collected on cases they have claimed.
Paying the debt in full at a branch releases held vehicles and closes the loan.

## Staff commands

`/setcredit [id or State ID] [score]`, `/releasevehicle [plate]`, `/closecase [case id]`. Each needs its `command.<name>` ace.

## Exports (server)

`GetAccount(numberOrJob)`, `GetPersonalAccount(cid)`, `GetAccountBalance(numberOrJob)`, `AddMoney(numberOrJob, amount, reason)`,
`RemoveMoney(numberOrJob, amount, reason)`, `AddTransaction(numberOrJob, kind, amount, reason)`, `GetCreditScore(cid)`,
`AddCreditEvent(cid, delta, reason)`, `IsVehicleHeld(plate)`, `ReleaseVehicle(plate)`, `HasDebt(cid)`.
camelCase versions also exist.

Server events for other scripts: `vr-banking:server:vehicleSeized (plate, cid, caseId, model)`,
`vr-banking:server:vehicleReleased (plate, cid, caseId)`, `vr-banking:server:caseOpened`, `vr-banking:server:creditChanged`,
`vr-banking:server:transaction`. Garages should refuse to spawn a plate while `IsVehicleHeld(plate)` is true.

## Tables

Created on start: `vr_bank_accounts`, `vr_bank_members`, `vr_bank_transactions`, `vr_bank_cards`, `vr_bank_credit`,
`vr_bank_credit_log`, `vr_bank_loans`, `vr_bank_cases`, `vr_bank_repos`.
