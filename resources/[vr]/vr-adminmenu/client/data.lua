local PedList = require "data.ped"

local function GetVehicles()
    local vehicles = {}

    for _, v in pairs(VRCore.Shared.Vehicles or {}) do
        vehicles[#vehicles + 1] = { label = v.name, value = v.model }
    end

    return vehicles
end

local function GetItems()
    local items = {}

    if GetResourceState('vr-inventory') ~= 'started' then return items end

    local ok, ItemsData = pcall(function() return exports['vr-inventory']:Items() end)
    if not ok or type(ItemsData) ~= 'table' then return items end

    for name, v in pairs(ItemsData) do
        items[#items + 1] = {
            label = v.label or v.name or name,
            value = v.name or name
        }
    end

    return items
end

local function GetJobs()
    local jobs = {}

    for name, v in pairs(VRCore.Shared.Jobs or {}) do
        local gradeDataList = {}

        for grade, gradeData in pairs(v.grades or {}) do
            gradeDataList[#gradeDataList + 1] = { name = gradeData.name, grade = grade, isboss = gradeData.isboss }
        end

        jobs[#jobs + 1] = { label = v.label, value = name, grades = gradeDataList }
    end

    return jobs
end

local function GetGangs()
    local gangs = {}

    for name, v in pairs(VRCore.Shared.Gangs or {}) do
        local gradeDataList = {}

        for grade, gradeData in pairs(v.grades or {}) do
            gradeDataList[#gradeDataList + 1] = { name = gradeData.name, grade = grade, isboss = gradeData.isboss }
        end

        gangs[#gangs + 1] = { label = v.label, value = name, grades = gradeDataList }
    end

    return gangs
end

local function GetLocations()
    local LocationList = VRCore.Shared.Locations
    if type(LocationList) ~= 'table' or not next(LocationList) then
        LocationList = require "data.locations"
    end

    local locations = {}
    for name, v in pairs(LocationList) do
        locations[#locations + 1] = { label = name, value = v }
    end

    return locations
end

function GetData()
    local items = GetItems()
    SendNUIMessage({
        action = "data",
        data = {
            vehicles = GetVehicles(),
            items = items,
            jobs = GetJobs(),
            gangs = GetGangs(),
            locations = GetLocations(),
            pedlist = PedList
        },
    })
    return next(items) ~= nil
end
