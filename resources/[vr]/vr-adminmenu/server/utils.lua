local Ranks = { mod = 1, admin = 2, god = 3 }
local RankNames = { 'mod', 'admin', 'god' }

local function noPerms(source)
    VRCore.Functions.Notify(source, locale('no_perms'), 'error')
end

function HasPerms(source, perms)
    source = tonumber(source)
    if not source or source <= 0 then return false end
    if type(perms) ~= 'string' and type(perms) ~= 'table' then return false end
    return VRCore.Functions.HasPermission(source, perms) == true
end

function CheckPerms(source, perms)
    if HasPerms(source, perms) then return true end
    if tonumber(source) and tonumber(source) > 0 then noPerms(source) end
    return false
end

function GetRank(source)
    for i = #RankNames, 1, -1 do
        if HasPerms(source, RankNames[i]) then return i end
    end
    return 0
end

function RankOf(name)
    return Ranks[name]
end

function CanActOn(source, target)
    if tonumber(source) == tonumber(target) then return true end
    if GetRank(target) > GetRank(source) then
        VRCore.Functions.Notify(source, locale('target_higher_rank'), 'error', 7500)
        return false
    end
    return true
end

function GetActionByKey(key)
    if type(key) ~= 'string' then return nil end
    local action = Config.Actions[key]
    if action then
        if action.event then return action end
        if action.dropdown then
            for _, v in pairs(action.dropdown) do
                if v.event then
                    return { label = action.label, type = v.type, event = v.event, perms = action.perms }
                end
            end
        end
        return nil
    end
    return Config.PlayerActions[key] or Config.OtherActions[key]
end

CheckDataFromKey = GetActionByKey

local EventPerms = {}
local AllowedValues = {}

local function addEventPerms(event, perms)
    if type(event) ~= 'string' or perms == nil then return end
    local list = EventPerms[event] or {}
    for i = 1, #list do
        if list[i] == perms then return end
    end
    list[#list + 1] = perms
    EventPerms[event] = list
end

local function indexActions(actions)
    for _, action in pairs(actions or {}) do
        if action.event then addEventPerms(action.event, action.perms) end
        if action.dropdown then
            local button
            for _, v in pairs(action.dropdown) do
                if v.event then
                    button = v
                    addEventPerms(v.event, action.perms)
                end
            end
            if button then
                local values = AllowedValues[button.event] or {}
                for _, v in pairs(action.dropdown) do
                    if v.label and type(v.data) == 'table' then
                        local set = values[v.label] or {}
                        for _, opt in pairs(v.data) do
                            if opt.value ~= nil then set[tostring(opt.value)] = true end
                        end
                        values[v.label] = set
                    end
                end
                AllowedValues[button.event] = values
            end
        end
    end
end

indexActions(Config.Actions)
indexActions(Config.PlayerActions)
indexActions(Config.OtherActions)

function Authorize(source, event, selectedData, silent)
    local perms = EventPerms[event]
    if not perms then
        if not silent then noPerms(source) end
        return false
    end
    for i = 1, #perms do
        if not HasPerms(source, perms[i]) then
            if not silent then noPerms(source) end
            return false
        end
    end
    if not silent then AdminLog(source, event, selectedData) end
    return true
end

function IsAllowedValue(event, label, value)
    local set = AllowedValues[event] and AllowedValues[event][label]
    if not set then return nil end
    return value ~= nil and set[tostring(value)] == true
end

function Field(selectedData, label, key)
    if type(selectedData) ~= 'table' then return nil end
    local f = selectedData[label]
    if type(f) ~= 'table' then return nil end
    return f[key or 'value']
end

function GetTargetId(value)
    local id = tonumber(value)
    if not id or id <= 0 or id ~= math.floor(id) then return nil end
    if not GetPlayerName(id) then return nil end
    return id
end

function GetTargetPlayer(value)
    local id = GetTargetId(value)
    if not id then return nil end
    local player = VRCore.Functions.GetPlayer(id)
    if not player then return nil end
    return id, player
end

function ToAmount(value, max)
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n <= 0 or n ~= math.floor(n) then return nil end
    if max and n > max then return nil end
    return math.floor(n)
end

function CleanText(value, maxLen)
    if type(value) == 'number' then value = tostring(value) end
    if type(value) ~= 'string' then return nil end
    value = value:gsub('%c', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if maxLen and #value > maxLen then value = value:sub(1, maxLen) end
    return value
end

function Trim(value)
    return (tostring(value):gsub('^%s+', ''):gsub('%s+$', ''))
end

function CleanPlate(value)
    if type(value) ~= 'string' then return nil end
    local plate = Trim(value):upper()
    if #plate < 1 or #plate > 8 or plate:find('[^%w ]') then return nil end
    return plate
end

function LoadDataFile(file)
    local resource = GetCurrentResourceName()
    local src = LoadResourceFile(resource, file)
    if not src then return nil end
    local fn = load(src, ('@@%s/%s'):format(resource, file))
    if not fn then return nil end
    local ok, result = pcall(fn)
    return ok and result or nil
end

function FullName(player)
    local ci = player and player.PlayerData and player.PlayerData.charinfo
    if not ci then return 'Unknown' end
    return ('%s %s'):format(ci.firstname or '', ci.lastname or '')
end

function ResourceUp(key)
    local name = Config.Resources[key]
    return type(name) == 'string' and GetResourceState(name) == 'started'
end

function CallExport(key, fn, ...)
    if not ResourceUp(key) then return false end
    local res = exports[Config.Resources[key]]
    local args = table.pack(...)
    return pcall(function() return res[fn](res, table.unpack(args, 1, args.n)) end)
end

function AdminLog(source, action, selectedData)
    if not ResourceUp('logs') then return end
    local player = VRCore.Functions.GetPlayer(source)
    local who = ('%s (%s | id %s)'):format(GetPlayerName(source) or 'unknown', player and player.PlayerData.citizenid or 'n/a', source)
    local args = type(selectedData) == 'table' and (' with args: ' .. json.encode(selectedData)) or ''
    TriggerEvent(Config.Resources.logs .. ':server:CreateLog', 'vr-adminmenu', 'Action Used: ' .. tostring(action), 'red',
        ('%s - Used: %s%s'):format(who, tostring(action), args))
end

local tableCache = {}

function TableExists(name)
    if tableCache[name] ~= nil then return tableCache[name] end
    local ok, result = pcall(MySQL.scalar.await,
        'SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?', { name })
    local exists = ok and tonumber(result) ~= nil and tonumber(result) > 0
    tableCache[name] = exists
    return exists
end

function VehicleTableReady(source)
    if TableExists(Config.VehicleTable) then return true end
    if source then VRCore.Functions.Notify(source, locale('no_vehicle_table'), 'error', 7500) end
    return false
end

function CheckAlreadyPlate(plate)
    if not TableExists(Config.VehicleTable) then return false end
    local result = MySQL.single.await(('SELECT plate FROM `%s` WHERE plate = ?'):format(Config.VehicleTable), { Trim(plate) })
    return result ~= nil and result.plate ~= nil
end

function CheckRoutingbucket(source, target)
    local sourceBucket = GetPlayerRoutingBucket(source)
    local targetBucket = GetPlayerRoutingBucket(target)

    if sourceBucket == targetBucket then return end

    VRCore.Functions.SetPlayerBucket(source, targetBucket)
    VRCore.Functions.Notify(source, locale("bucket_set", targetBucket), 'error', 7500)
end

lib.callback.register('vr-adminmenu:callback:CheckPerms', function(source, perms)
    if type(perms) ~= 'string' or not Ranks[perms] then return false end
    return HasPerms(source, perms)
end)
