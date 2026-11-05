# vr-dealership

Vehicle dealerships for ValRavn. Sales go through vr-garages (registration and plates) and vr-banking (finance). No outside calls.

## How buying works

- Use the eye on the dealership desk and pick **Browse vehicles**. Each dealership sells the vr-core vehicles with a matching `shop`
  (`pdm`, `luxury`, `boats`, `air`, `truck`).
- **Preview** shows the car in the showroom with a camera you can drag to turn. **Test drive** gives you the car for
  `Config.TestDrive.seconds`. It ends early if you leave the car or drive too far, and you are brought back.
- **Self-service** (`Config.SelfService.mode`): `offline` means customers can only buy on their own when no salesperson is on duty,
  `always` or `never` do what they say.
- Payment: bank, cash or **bank finance**. Finance needs a down payment (`minDownPercent` in vr-banking) and creates a car finance
  loan with the car as collateral. Missed payments lead to collections and repossession like any other loan.
- Bosses can **buy for the company**: paid from the job's society account and added to the job fleet.
- New cars are delivered outside. If the delivery spot is blocked, the car waits at the dealership's garage.

## Sales job

Add players to the `cardealer` job. They clock in at the desk, then use the desk or `/salestablet` on the sales floor.

- Pick a car and a customer standing next to you, set the price and choose full payment or bank finance (you can check if the bank would approve first).
- Each grade can go down by `Config.Sales.discountByGrade` percent and up by `maxMarkupPercent`.
- The customer gets the offer on screen and has `offerSeconds` to accept.
- The salesperson earns `commissionPercent` of the price. The dealership account gets `societyPercent` (self-service sales give `SelfService.societyPercent`).
- From grade `displayGrade` staff can choose which cars stand on the showroom floor.

## Placing things in game

`/dealer [kiosk|delivery|testdrive|return|preview|center] [dealer id]` moves that point to where you stand (or your car),
`/dealer radius [id] [m]`, `/dealer display [id] [model]` adds a showroom spot, `/dealer cleardisplay [id]`, `/dealer list`.
Needs `command.dealer` or admin. Changes are saved in `vr_dealership_locations` **of the server you ran the command on**. The database is not part of your repo, so a server you pushed to will not have them.
`/dealer export [id]` prints a ready-made block for `Config.Dealers` and writes it to `exports/<id>.lua`, paste it into `config.lua` so the location travels with the code.

`/dealercheck` (admin or the server console) tests the setup and prints what is wrong: database and tables, vr-garages, the vehicle list, the job, OneSync (the server has to be able to read your position), and how far you are from each dealership.

## Exports and events

Server exports: `GetDealers()`, `IsStaff(src)`, `IsTestDriving(src)`. Server event `vr-dealership:server:sold` fires with the sale details.
Every sale is logged in `vr_dealership_sales`.
