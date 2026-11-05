local U = InvUtil
local isServer = IsDuplicityVersion()

ItemList = {}

local function loadData(name)
    local file = ('data/%s.lua'):format(name)
    local chunk = LoadResourceFile(shared.resource, file)
    if not chunk then return {} end
    local fn, err = load(chunk, ('@@%s/%s'):format(shared.resource, file))
    if not fn then
        print(('^1[vr-inventory] %s failed to load: %s^0'):format(file, err))
        return {}
    end
    local ok, result = pcall(fn)
    if not ok then
        print(('^1[vr-inventory] %s failed to run: %s^0'):format(file, result))
        return {}
    end
    return type(result) == 'table' and result or {}
end

InvData = loadData

local function useExport(target)
    local resource, export = target:match('^(.-)%.(.+)$')
    if not resource then return nil end
    return function(...)
        if GetResourceState(resource) ~= 'started' then
            if not IsDuplicityVersion() then
                lib.notify({ id = 'cannot_perform', type = 'error', description = locale('cannot_perform') })
            end
            print(('^3[vr-inventory] %s is not running, so the item export %s can\'t be used^0'):format(resource, target))
            return false
        end
        return exports[resource][export](nil, ...)
    end
end

local function imagePath(path)
    if type(path) ~= 'string' then return nil end
    if path:match('^[%w]+://') then return path end
    return ('%s/%s'):format(client.imagepath, path)
end

local function addItem(name, data)
    data.name = name
    data.weight = tonumber(data.weight) or 0
    if data.close == nil then data.close = true end
    if data.stack == nil then data.stack = true end

    local clientData, serverData = data.client, data.server

    if not data.consume and ((clientData and (clientData.status or clientData.usetime or clientData.export)) or (serverData and serverData.export)) then
        data.consume = 1
    end

    if isServer then
        data.client = nil
        if not data.durability and (data.degrade or (data.consume and data.consume ~= 0 and data.consume < 1)) then
            data.durability = true
        end
        if serverData and serverData.export then data.cb = useExport(serverData.export) end
    else
        data.server = nil
        data.count = 0
        if clientData then
            if clientData.export then data.export = useExport(clientData.export) end
            clientData.image = imagePath(clientData.image)
            if clientData.propTwo then
                clientData.prop = clientData.prop and { clientData.prop, clientData.propTwo } or clientData.propTwo
                clientData.propTwo = nil
            end
        end
    end

    ItemList[name] = data
end

for kind, list in pairs(loadData('weapons')) do
    for name, data in pairs(list) do
        data.name = name
        data.close = kind == 'Ammo'
        data.weight = tonumber(data.weight) or 0

        if kind == 'Weapons' then
            data.model = data.model or name
            data.hash = joaat(data.model)
            data.stack = data.throwable and true or false
            data.durability = data.durability or 0.05
            data.weapon = true
        else
            data.stack = true
        end

        if kind == 'Ammo' then data.ammo = true
        elseif kind == 'Components' then data.component = true
        elseif kind == 'Tints' then data.tint = true
        else data.weapon = true end

        if isServer then
            data.client = nil
        else
            data.count = 0
            data.server = nil
            if data.client and data.client.image then data.client.image = imagePath(data.client.image) end
        end

        ItemList[name] = data
    end
end

for name, data in pairs(loadData('items')) do
    local ok, err = pcall(addItem, name, data)
    if not ok then print(('^1[vr-inventory] item "%s" could not be created: %s^0'):format(name, err)) end
end

ItemList.cash = ItemList.money

function InvGetItem(name)
    if name == nil then return ItemList end
    if type(name) ~= 'string' then return nil end
    return ItemList[U.itemName(name)]
end

Hashes = {
    petrolcan = joaat('WEAPON_PETROLCAN'),
    hazardcan = joaat('WEAPON_HAZARDCAN'),
    fertilizercan = joaat('WEAPON_FERTILIZERCAN'),
    extinguisher = joaat('WEAPON_FIREEXTINGUISHER'),
    stungun = joaat('WEAPON_STUNGUN'),
}

function Hashes.isCan(hash)
    return hash == Hashes.petrolcan or hash == Hashes.hazardcan or hash == Hashes.fertilizercan or hash == Hashes.extinguisher
end
