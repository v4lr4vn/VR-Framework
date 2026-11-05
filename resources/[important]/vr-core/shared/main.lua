local VRCore = VRCore

VRCore.Shared          = {}
VRCore.ClientCallbacks = {}
VRCore.ServerCallbacks = {}

local bridge = VRCore.Config.QBBridge

ExportedNames = {}

function CoreExport(name, fn)
    ExportedNames[name] = true
    exports(name, fn)
    if bridge then
        AddEventHandler(('__cfx_export_qb-core_%s'):format(name), function(setCB) setCB(fn) end)
    end
end

function CoreEmit(name, ...)
    TriggerEvent('VRCore:' .. name, ...)
    if bridge then TriggerEvent('QBCore:' .. name, ...) end
end

function CoreOnNet(name, fn)
    RegisterNetEvent('VRCore:' .. name, fn)
    if bridge then RegisterNetEvent('QBCore:' .. name, fn) end
end

local function GetCoreObject(filters)
    if not filters then return VRCore end
    local results = {}
    for i = 1, #filters do
        local key = filters[i]
        if VRCore[key] then results[key] = VRCore[key] end
    end
    return results
end
CoreExport('GetCoreObject', GetCoreObject)

local function GetShared(namespace, item)
    local ns = VRCore.Shared[namespace]
    if not ns then return nil end
    if item then return ns[item] end
    return ns
end
CoreExport('GetShared', GetShared)
