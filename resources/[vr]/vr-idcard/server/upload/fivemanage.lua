local uploadType = require('config').mugshotsUpload

if uploadType ~= 'fivemanage' then return end

local TOKEN = GetConvar("fivemanage:key", "")

if TOKEN == '' then
    warn('Fivemanage token is not set in server.cfg (set fivemanage:key "YOUR_TOKEN")')
    return
end

local PRESIGNED_URL = 'https://api.fivemanage.com/api/v3/file/presigned-url'

local function GetPresignedUrl()
    local statusCode, response = PerformHttpRequestAwait(PRESIGNED_URL, 'GET', '', { ['Authorization'] = TOKEN })

    if statusCode ~= 200 then
        warn(('Failed to get presigned URL (status: %s)'):format(statusCode))
        return nil
    end

    local data = json.decode(response )
    local presignedUrl = data?.data?.presignedUrl
    if not presignedUrl then
        warn('Invalid presigned URL response')
        return nil
    end

    return presignedUrl
end

local function IsAllowedMugshotUrl(result)
    local url = result.url
    if not url or type(url) ~= 'string' or url == '' or not url:find('^https://') then return nil end
    local allowed = { 'https://r2.fivemanage.com', 'https://fivemanage.com' }
    for i = 1, #allowed do
        local origin = allowed[i]
        if origin and #url >= #origin and url:sub(1, #origin) == origin then return url end
    end
    return nil
end

lib.callback.register('vr-idcard:server:getPresignedUrl', function(source)
    return GetPresignedUrl()
end)

return IsAllowedMugshotUrl