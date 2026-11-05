local DiscordAPI = require 'api/main'
local Roles = require 'queue/roles'
local Debug = require 'queue/debug'
local Card = require 'queue/card'
local Webhook = require 'queue/webhook'

local maxPlayersConvar = GetConvarInt('sv_maxclients', 48)
local function convarInt(name, default) return GetConvarInt('vr:' .. name, GetConvarInt('ps:' .. name, default)) end
local function convar(name, default) return GetConvar('vr:' .. name, GetConvar('ps:' .. name, default)) end

local displayQueueInHostname = convarInt('displayQueueInHostname', 1) == 1
local gracePeriod = convarInt('gracePeriod', 0)
local ghostCheckInterval = convarInt('ghostCheckInterval', 30)
local requireMember = convarInt('discordRequireMember', 1) == 1
local hostname = GetConvar('sv_hostname', 'ValRavn')
local webhookStatusMessage = convar('webhookStatusMessage', '')
local webhookStatusUpdateInterval = math.max(10, convarInt('webhookStatusUpdateInterval', 30))
local discordChecks = DiscordAPI:IsConfigured()

if not discordChecks then
    print('^3[vr-discord] No bot token or guild id set (vr:discordBotToken / vr:discordGuildId): the queue runs without Discord role checks.^7')
end

local Queue = {}
local inQueue = {}
local recentlyLeft = {}
local shouldQueueRun = false
local webhookStatusMessageId = GetResourceKvpString('vrdiscord:webhookStatusMessageId') or ''
local queueCounter = 0

local function sortQueue()
    local usersWithPriority = {}

    for _, data in ipairs(inQueue) do
        if data.priority > 0 then
            table.insert(usersWithPriority, data)
        end
    end

    table.sort(usersWithPriority, function(a, b)
        if a.priority == b.priority then
            return a.index < b.index
        else
            return a.priority < b.priority
        end
    end)

    local finalyQueueList = {}

    for _, data in ipairs(usersWithPriority) do
        table.insert(finalyQueueList, data)
    end

    for _, data in ipairs(inQueue) do
        if data.priority == 0 then
            table.insert(finalyQueueList, data)
        end
    end

    inQueue = finalyQueueList
end

local function setAdaptiveCard(deferrals, queueNumber, totalInQueue)
    local card = Card:Build(queueNumber, totalInQueue)
    deferrals.presentCard(card)
end

local function updateQueueNumbers()
    for i, data in ipairs(inQueue) do
        setAdaptiveCard(data.deferrals, i, #inQueue)
    end

    if displayQueueInHostname and #inQueue > 0 then
        local withQueue = string.format('[%s] %s', #inQueue, hostname)
        SetConvar('sv_hostname', withQueue)
    end
end

local lastGhostCheck = nil
local function checkForGhostPlayers()
    if lastGhostCheck and lastGhostCheck + ghostCheckInterval > os.time() then
        return
    end

    for i = #inQueue, 1, -1 do
        if not GetPlayerName(inQueue[i].source) then
            table.remove(inQueue, i)
        end
    end
    updateQueueNumbers()

    lastGhostCheck = os.time()
end

local function generateStatusMessage()
    return {
        username = hostname,
        embeds = {
            {
                title = hostname,
                description = 'Here\'s the latest data straight from our server!',
                color = 0x3d20d2,
                fields = {
                    {
                        name = 'Players',
                        value = string.format('`%s`', #GetPlayers()),
                        inline = true
                    },
                    {
                        name = 'In Queue',
                        value = string.format('`%s`', #inQueue),
                        inline = true
                    }
                }
            }
        }
    }
end

local isCreating = false
local function checkForEmbedPost()
    if isCreating or webhookStatusMessage == '' then return end

    if not webhookStatusMessageId or webhookStatusMessageId == '' then
        isCreating = true
        local message = generateStatusMessage()

        Webhook:Send(webhookStatusMessage, message, function(statusCode, response, headers, error)
            local ok, data = pcall(json.decode, response or '')

            if ok and type(data) == 'table' and data.id then
                SetResourceKvp('vrdiscord:webhookStatusMessageId', data.id)
                webhookStatusMessageId = data.id
            end

            isCreating = false
        end, true)
    else
        Webhook:EditMessage(webhookStatusMessage, webhookStatusMessageId, generateStatusMessage())
    end
end

local function startQueue()
    shouldQueueRun = true

    CreateThread(function()
        while shouldQueueRun do
            Citizen.Wait(1000)

            checkForGhostPlayers()

            local playersInServer = #GetPlayers()
            if #inQueue > 0 and playersInServer < maxPlayersConvar then
                local data = table.remove(inQueue, 1)

                data.deferrals.done()
                Debug(string.format('[vr-discord] %s has connected successfully', GetPlayerName(data.source) or data.identifier))

                updateQueueNumbers()
            end

            if #inQueue == 0 then
                SetConvar('sv_hostname', hostname)
                shouldQueueRun = false
                break
            end
        end
    end)
end

local onQueueAddCallbacks = {}
local function enqueue(source, identifier, priority, deferrals)
    if gracePeriod > 0 and identifier then
        for _, data in ipairs(recentlyLeft) do
            if data.time + gracePeriod > os.time() and data.identifier == identifier then
                priority = math.min(priority, #Roles.priorityRoles + 1)
            end
        end
    end

    queueCounter = queueCounter + 1
    table.insert(inQueue, {
        source = source,
        identifier = identifier or ('player:' .. tostring(source)),
        priority = priority,
        deferrals = deferrals,
        index = queueCounter
    })
    sortQueue()
    deferrals.update(string.format(Lang.inQueue, #inQueue))
    updateQueueNumbers()

    CreateThread(function()
        for _, callback in ipairs(onQueueAddCallbacks) do
            callback(identifier, priority)
        end
    end)

    if not shouldQueueRun then
        startQueue()
    end
end

function Queue:DiscordChecks()
    return discordChecks
end

function Queue:AddToQueue(source, identifier, deferrals)
    deferrals.defer()
    Wait(0)
    deferrals.update(Lang.connecting)

    if not discordChecks then
        enqueue(source, identifier, 1000, deferrals)
        return
    end

    local strict = requireMember or #Roles.allowlistedRoles > 0

    DiscordAPI:FetchMemberInfo(identifier, function(user, status)
        if not user then
            if status == 404 then
                if strict then return deferrals.done(Lang.failedToFindDiscord) end
            elseif strict then
                return deferrals.done(Lang.discordUnavailable)
            end
            enqueue(source, identifier, 1000, deferrals)
            return
        end

        Debug(string.format('[vr-discord] Found Discord user %s (%s)', user.user and user.user.username or '?', identifier))

        local roles = user.roles or {}
        local hasRole = false

        if #Roles.allowlistedRoles == 0 then
            hasRole = true
        end

        local priority = 1000
        for _, role in ipairs(roles) do
            if not hasRole then
                for _, allowedRole in ipairs(Roles.allowlistedRoles) do
                    if role == allowedRole then
                        hasRole = true
                        break
                    end
                end
            end

            for prio, priorityRole in ipairs(Roles.priorityRoles) do
                if role == priorityRole then
                    priority = prio
                end
            end
        end

        if not hasRole then
            deferrals.done(Lang.noRole)
            return
        end

        enqueue(source, identifier, priority, deferrals)
    end)
end

function Queue:PlayerLeft(identifier)
    for i, data in ipairs(inQueue) do
        if data.identifier == identifier then
            table.remove(inQueue, i)
            updateQueueNumbers()
            break
        end
    end
end

function Queue:AddToGrace(identifier)
    if gracePeriod > 0 then
        local t = os.time()
        for i = #recentlyLeft, 1, -1 do
            if recentlyLeft[i].time + gracePeriod <= t then table.remove(recentlyLeft, i) end
        end
        table.insert(recentlyLeft, { identifier = identifier, time = t })
    end
end

local function getQueueStatus(identifier)
    local queueNumber = 0
    for i, data in ipairs(inQueue) do
        if data.identifier == identifier then
            queueNumber = i
            break
        end
    end

    return queueNumber, #inQueue
end

exports('GetQueueStatus', getQueueStatus)

local function updatePriority(identifier, priority)
    priority = tonumber(priority)
    if not priority then return false end
    for _, data in ipairs(inQueue) do
        if data.identifier == identifier then
            data.priority = priority
            sortQueue()
            updateQueueNumbers()
            Debug(string.format('[vr-discord] %s priority set to %s via export', identifier, priority))
            return true
        end
    end

    return false
end

exports('UpdateQueuePriority', updatePriority)

local function forceRefresh()
    updateQueueNumbers()
    Debug('[vr-discord] Force refreshed queue numbers via export')
end

exports('ForceRefreshQueue', forceRefresh)

local function onQueueAdded(callback)
    if type(callback) ~= 'function' and type(callback) ~= 'table' then return end
    table.insert(onQueueAddCallbacks, callback)
end

exports('OnQueueAdded', onQueueAdded)

if webhookStatusMessage ~= '' then
    CreateThread(function()
        while true do
            checkForEmbedPost()
            Citizen.Wait(webhookStatusUpdateInterval * 1000)
        end
    end)
end

RegisterCommand("clearWebhookStatus", function(source)
    webhookStatusMessageId = ''
    SetResourceKvp('vrdiscord:webhookStatusMessageId', '')
end, true)

return Queue
