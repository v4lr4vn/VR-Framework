# vr-realtor

The real estate tablet for **vr-housing**. It's a port of [ps-realtor](https://github.com/Project-Sloth/ps-realtor) by Xirvin & Project Sloth (GPL-3.0, see `LICENSE`).

Players with a job in `Config.RealtorJobNames` (default `realestate`) open it with `/housing`. Set `Config.UseItem = true` to also open it from an item.

## Grades

`Config.RealtorPerms` sets the minimum grade for each action. The server enforces these grades now, not just the UI:

| Action | Default grade |
|---|---|
| Change description, price, images, interior, door, garage | 1 |
| Put a property on or off the market | 0 |
| Sell a property to a player | 0 |
| List a new property | 2 |
| Delete a property | 2 |
| Put a player in an apartment | 2 |

Every value sent from the tablet is checked: prices, coordinates, interiors, image links and text length. Owner, keys and furniture are never taken from the client.
