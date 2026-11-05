# vr-mechanic

Mechanic job for ValRavn: parts wear out as you drive, mechanics replace them with parts from the counter, fit performance upgrades and cosmetic changes, and bill customers. No outside calls.

## Wear and breakdowns

- Every car has six parts: engine, brakes, clutch and gearbox, suspension, tyres and radiator. Each one goes from 100% down to 0%.
- Parts wear with distance (`Config.Wear.perKm`), faster at high speed (`fastSpeed`, `fastMultiplier`), and take a hit in crashes (`crash.per100Body`).
- The driver's game reports wear to the server every `reportSeconds`. The server only accepts reports from the driver, never lets a part go up, and caps the distance by time.
- Status is kept on the vehicle (`vr_status`, `vr_mileage`) and saved to `player_vehicles.status` and `drivingdistance` every `persistSeconds` and when the car is parked in vr-garages.
- Worn parts change how the car drives (`Config.Effects`): less power, weaker brakes, less grip, soft suspension. Very worn parts break down: the engine stalls, the clutch slips, tyres burst and a broken radiator slowly cooks the engine.
- Drivers get a warning when they get into a car with a part under `warnAt`.

## Mechanics

Put players in the `mechanic` job. They clock in at the workshop counter (eye target). On duty they get two options on any vehicle:

- **Inspect vehicle**: shows every part, engine and body health and the odometer. Replace a part, rebuild the engine or fix the bodywork. Each job takes one part item and a few seconds of work. This works anywhere, so mechanics can do roadside call-outs.
- **Customise vehicle**: only inside the workshop. Performance (engine, brakes, transmission, suspension, armour, turbo), paint and finish, pearlescent, wheels, wheel colour, xenons, neons, window tint, plates, horn, livery and body parts. Changes show on the car as you pick them.
  The order is priced from `Config.Tuning` and sent as a bill to a customer standing nearby. They see every line and the total and have `BillSeconds` to pay by bank or cash. If they pay, everything is fitted and saved to the car. If they decline or the time runs out, the changes come off.
  A mechanic can also pay for work on their own car, and from grade `Config.Shop.companyGrade` charge it to the company account.
- `/mechbill` (or **Bill a customer** in the inspection) sends any other bill, for example a tow or labour.

Nothing is fitted the moment a bill is paid. A paid job becomes a **work order**, and the mechanic fits each part by hand: the character walks to the right spot on the car and plays an animation (spray can for paint and liveries, kneeling at the wheel, lying under the car for suspension and neons, welding for body parts, working under the hood for engine parts). **Fit everything** works through the whole list. Each part shows up on the car when it is done. Times per kind of work are in `Config.FitSeconds`.

## Customer orders

Customers can design their own look. They bring their own car into any workshop and use the third eye on it: **Design a new look**. They see the changes on a copy of their car with a camera they can drag around (the real car is not touched). Only cosmetics can be picked here, no performance parts.

**Place order** gives them an **order sheet** item (`mechanic_order`). They hand it to a mechanic, or the mechanic finds it on the **Work orders** board at the counter. The mechanic sends the bill when the car and the customer are at the workshop (`Config.Orders.billDistance`). Once it is paid, they fit the parts as above. When the order is finished the sheet is taken back and the customer gets a message.

Customers can open their sheet to see the progress or cancel an order that has not been billed yet. A customer can have `Config.Orders.maxOpen` open orders, and unbilled orders expire after `expireDays`.

The mechanic gets `CommissionPercent` of every paid bill, the rest goes to the job's society account. Every bill is logged in `vr_mechanic_jobs`.

## Parts

The parts counter sells `engine_parts`, `brake_pads`, `clutch_kit`, `suspension_parts`, `tyre_set`, `radiator_parts`, `body_panel` and `repair_kit` (prices in `Config.Shop`). Pay with bank or cash, or the company account from `companyGrade`.

Anyone can use a `repair_kit` next to a broken car. It brings the engine back to `Config.Repairs.repairKit.engineHealth` so the car can limp to a workshop.

## Placing workshops in game

`/workshop create [id] [label]` makes a new workshop where you stand. `/workshop center [id]`, `/workshop counter [id]`, `/workshop radius [id] [m]`, `/workshop label [id] [label]`, `/workshop job [id] [job]`, `/workshop delete [id]`, `/workshop list`.
Needs `command.workshop`. Changes are saved in `vr_mechanic_locations`.

## Exports and events

Server exports: `GetVehicleStatus(netId or plate)`, `SetVehicleStatus(netId, { brakes = 40 })`, `RepairVehicle(netId, full)`, `IsMechanic(src)`, `GetWorkshops()`.
Client exports: `repairKit` (used by the `repair_kit` item) and `orderSheet` (used by the `mechanic_order` item).
Server events: `vr-mechanic:server:repaired` (plate, kind, part, src), `vr-mechanic:server:billPaid` (kind, mechanic, customer, amount, plate) and `vr-mechanic:server:fitted` (order id, part, plate, src). Orders are stored in `vr_mechanic_orders`.
