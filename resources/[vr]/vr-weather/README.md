# vr-weather

Synced weather, time and seasons for ValRavn. Server authoritative, saved between restarts, no outside calls.

## Day length

One in-game day lasts `Config.Time.dayLengthMinutes` real minutes (default 150, so 2h30m).
`nightShare` is the part of that day spent at night (21:00 to 06:00). `0.3` means nights take 30% of the day.
Set it to `0` for an even clock.

Admins can change the day length live from the panel or with `/daylength [minutes]`. The live value is kept
until you change the number in `config.lua`, then the config wins again.

Turn on `Config.Time.realTime.enabled` to follow real UK time (GMT and BST handled).

## Seasons

The season follows the real month (`Config.Seasons.byMonth`): winter Dec to Feb, spring Mar to May,
summer Jun to Aug, autumn Sep to Nov. Each season has its own weather weights and temperature range.
Snow only settles on the ground in winter. Weather moves through natural steps (`Config.Transitions`),
so clear skies cloud over before it rains.

`Config.Holidays` forces a weather type on a date (Halloween on 31 October, deep snow on 25 December).

## Commands

All need the matching `command.<name>` ace. `Config.AdminAce` (default `command.weather`) guards the panel.

| Command | What it does |
| --- | --- |
| `/weather` | Opens the weather panel |
| `/weather [type]` | Sets the weather |
| `/time [hour] [minute]` | Sets the clock |
| `/morning` `/noon` `/evening` `/night` | Quick times |
| `/freezetime [on/off]` | Stops the clock |
| `/freezeweather [on/off]` | Stops weather changes |
| `/dynamicweather [on/off]` | Turns the weather cycle on or off |
| `/blackout [on/off]` | City-wide power cut |
| `/daylength [minutes]` | Real minutes per in-game day |
| `/forecast` | Anyone: current weather and what is next |

## Exports

Server: `getWeather`, `setWeather`, `getTime`, `setTime`, `getBlackoutState`, `setBlackout`, `getTimeFreezeState`,
`setTimeFreeze`, `getWeatherFreezeState`, `setWeatherFreeze`, `getDynamicWeather`, `setDynamicWeather`,
`nextWeatherStage`, `getSeason`, `getForecast`, `getTemperature`, `getDayLength`, `setDayLength`.

Client: `getWeather`, `getTime`, `getSeason`, `getTemperature`, `isBlackout`, `isSynced`, `setSynced`.

## Compatibility

Provides `qb-weathersync` and `vr-weathersync`. Their exports, server events and the
`qb-weathersync:client:DisableSync` / `EnableSync` client events (used by housing interiors) all work.
