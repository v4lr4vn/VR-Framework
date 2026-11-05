local DeletePed    = DeletePed
station            = nil
player             = {}
player.nearStation = false
local stations     = {}

for index, station in pairs(Config.PoliceStations) do
    local cfg = station

    if cfg.blip.enable then
        utils.createBlip(cfg.blip)
    end

    stations[#stations + 1] = lib.zones.box({
        name = 'police',
        coords = cfg.zone.pos,
        size = cfg.zone.size,
        clothes = Config.ClothingScript and cfg.clothes,
        rotation = 0.0,
        onEnter = function(self)
            if self.clothes then
                initClothes(self.clothes, station.jobs)
            end
            cfg.armory.jobs = station.jobs
            cfg.armory.stationId = index
            initArmory(cfg.armory)
            initGarage(cfg.garage, station.jobs)
            player.nearStation = true
        end,
        onExit = function(self)
            for k, v in pairs(peds) do
                if DoesEntityExist(v) then
                    DeletePed(v)
                end
            end
            player.nearStation = false
        end
    })
end

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end
    for k, v in pairs(peds) do
        if DoesEntityExist(v) then
            DeletePed(v)
        end
    end
end)
