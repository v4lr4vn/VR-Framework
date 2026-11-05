local QueueSystem = require 'api/queue'
local Debug = require 'queue/debug'

local API = {}

local discordAPIVersion = GetConvarInt('vr:discordAPIVersion', GetConvarInt('ps:discordAPIVersion', 10))
local discordGuildId = GetConvar('vr:discordGuildId', GetConvar('ps:discordGuildId', ''))
local discordBotToken = GetConvar('vr:discordBotToken', GetConvar('ps:discordBotToken', ''))

function API:IsConfigured()
    return discordGuildId ~= '' and discordBotToken ~= ''
end

function API:FetchMemberInfo(discordId, callback)
    local function responseCallback(respCode, resultData, result, error)
        if respCode ~= 200 then
            Debug(string.format('[vr-discord] Failed to fetch member info for %s (HTTP %s)', discordId, tostring(respCode)))
            callback(false, respCode)
            return
        end

        local data = json.decode(resultData)

        if not data then
            Debug(string.format('[vr-discord] Failed to decode member info for %s', discordId))
            callback(false, 0)
            return
        end

        callback(data)
    end

    local request = {
        url = string.format('https://discord.com/api/v%s/guilds/%s/members/%s', discordAPIVersion, discordGuildId,
            discordId),
        method = 'GET',
        headers = {
            ['Content-Type'] = 'application/json',
            ['Authorization'] = 'Bot ' .. discordBotToken
        },
        callback = responseCallback
    }

    QueueSystem:ProcessRequest(request)
end

return API
