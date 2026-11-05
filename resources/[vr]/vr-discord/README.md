# vr-discord

A connection queue for ValRavn with an optional **Discord** allowlist and priority roles. It's a port of **ps-discord** by Walter and the Project Sloth Team (CC BY-NC-SA 4.0, see `LICENSE`).

## Out of the box

With no bot token and guild id set, vr-discord is a plain queue:
- everyone can join;
- players wait in line when the server is full;
- the number of players in the queue shows in the server name.

You'll see one line in the console saying so. Nobody is turned away.

## Turning on the Discord checks

Add to `server.cfg` (or a file it loads):

```cfg
set vr:discordBotToken "YOUR_BOT_TOKEN"     # keep this private, never share server.cfg
set vr:discordGuildId "YOUR_SERVER_ID"
```

Then, in `queue/roles.lua`:
- `allowlistedRoles`: only players with one of these roles can join. Leave it empty to allow every member of your Discord.
- `priorityRoles`: these roles skip ahead in the queue; earlier in the list goes first.

The bot must be in your Discord with the **Server Members Intent** turned on (Discord Developer Portal > Bot).

Once the checks are on:
- players need Discord linked to FiveM;
- with `vr:discordRequireMember 1` (the default), they must be in your Discord;
- if Discord can't be reached, the player is asked to try again rather than let in unchecked.

Set `vr:discordRequireMember 0` to only use Discord for priority.

## Changes from ps-discord

- **Safe start:** the original turned every player away when the token or guild wasn't set, or when Discord couldn't be reached. It now runs as a plain queue until you configure it.
- **Example role IDs:** the shipped config contained Project Sloth's own role IDs, which would have blocked everyone. The lists are now empty.
- **Fixes:**
  - A queue freeze: once the Discord rate limit was reached, the request loop waited forever, so every later player hung on "connecting".
  - A crash when Discord answered 429 without a body.
  - The ghost-player cleanup skipped entries.
  - Queue positions were wrong after people left.
  - Deferrals now wait a tick after `defer()`, as FiveM requires.
- **Branding:** the queue card, messages and webhook status now use your server name instead of Project Sloth's. The Docs/Discord buttons are off until you set your own in `queue/card.lua`.
- **Convars:** they use the `vr:` prefix (`vr:discordBotToken`, `vr:discordGuildId`, `vr:discordDebug`, `vr:discordRequestsPerMinute`, `vr:displayQueueInHostname`, `vr:gracePeriod`, `vr:ghostCheckInterval`, `vr:webhookStatusMessage`, `vr:webhookStatusUpdateInterval`, `vr:discordRequireMember`). The old `ps:` names still work.

## Optional status webhook

`set vr:webhookStatusMessage "https://discord.com/api/webhooks/..."` posts, and keeps editing, a message in that channel with the player and queue counts. Leave it unset and nothing is sent. Run `clearWebhookStatus` in the server console to start a new message.

## Original documentation

### Exports
#### `exports["vr-discord"]:GetQueueStatus(identifier)`
Gets the queue status of a player.

| Parameter | Type | Description |
| --- | --- | --- |
| `identifier` | STRING | The identifier of the player to get the queue status of. |

| Return | Type | Description |
| --- | --- | --- |
| queueNumber | INT | The queue number of the player. |
| queuePriority | INT | The queue priority of the player. |

#### `exports["vr-discord"]:UpdateQueuePriority(identifier, priority)`
Updates the queue priority of a player for this load only.

| Parameter | Type | Description |
| --- | --- | --- |
| `identifier` | STRING | The identifier of the player to update the queue priority of. |
| `priority` | INT | The new queue priority of the player. |

| Return | Type | Description |
| --- | --- | --- |
| success | BOOL | Whether or not the queue priority was updated. |

#### `exports["vr-discord"]:ForceRefreshQueue()`
Forces the queue to refresh everyones queue number and priority.

#### `exports["vr-discord"]:OnQueueAdded(callback)`
Adds a callback to be called when a player is added to the queue.

| Parameter | Type | Description |
| --- | --- | --- |
| `callback` | FUNCTION | The callback function to call when a player is added to the queue. |

**Example:**
```lua
exports["vr-discord"]:OnQueueAdded(function(identifier, priority)
    print("Player " .. identifier .. " was added to the queue with priority " .. priority)
end)
```

#### `exports["vr-discord"]:WebhookSend(webhook, data, callback, wait)`
Sends a message to a webhook.

| Parameter | Type | Description |
| --- | --- | --- |
| `webhook` | STRING | The webhook to send the message to. |
| `data` | TABLE | The data to send to the webhook. |
| `callback` | FUNCTION | The callback function to call when the request is done. |
| `wait` | BOOL | Set this to true if you wish to edit the message later, this will return the message in the reponse parameter of the callback |

#### `exports["vr-discord"]:WebhookEdit(webhook, message, data, callback)`
Edits a message sent by a webhook.

| Parameter | Type | Description |
| --- | --- | --- |
| `webhook` | STRING | The webhook to edit the message from. |
| `messageId` | STRING | The message id to edit. |
| `data` | TABLE | The data to send to the webhook. |
| `callback` | FUNCTION | The callback function to call when the request is done. |

#### `exports["vr-discord"]:WebhookSendMessage(webhook, name, title, color, message, tagEveryone, callback, wait)`
Sends a message to a webhook with a premade embed.

| Parameter | Type | Description |
| --- | --- | --- |
| `webhook` | STRING | The webhook to send the message to. |
| `name` | STRING | The name of the embed account sending the messaged |
| `title` | STRING | The title of the embed. |
| `color` | INT or STRING | The color of the embed. |
| `message` | STRING | The message of the embed. |
| `tagEveryone` | BOOL | Whether or not to tag everyone in the message. |
| `callback` | FUNCTION | The callback function to call when the request is done. |
| `wait` | BOOL | Set this to true if you wish to edit the message later, this will return the message in the reponse parameter of the callback |

#### `exports["vr-discord"]:WebhookEditMessage(webhook, messageId, name, title, color, message, tagEveryone, callback)`
Edits a message sent by a webhook with a premade embed.

| Parameter | Type | Description |
| --- | --- | --- |
| `webhook` | STRING | The webhook to edit the message from. |
| `messageId` | STRING | The message id to edit. |
| `name` | STRING | The name of the embed account sending the messaged |
| `title` | STRING | The title of the embed. |
| `color` | INT or STRING | The color of the embed. |
| `message` | STRING | The message of the embed. |
| `tagEveryone` | BOOL | Whether or not to tag everyone in the message. |
| `callback` | FUNCTION | The callback function to call when the request is done. |

## Preview
![image](https://github.com/Project-Sloth/ps-discord/assets/82112471/83b680c9-db2a-40aa-a958-ff68c58a81bb)
![image](https://github.com/Project-Sloth/ps-discord/assets/82112471/2bc02073-0779-44b0-ac78-e681e23d1e94)

## Credits
[Walter](https://github.com/Walter-00)
[complexza](https://github.com/complexza)
