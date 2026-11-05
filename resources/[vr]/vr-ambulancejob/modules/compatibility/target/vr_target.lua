local vrTarget = exports['vr-target']
Target = {}

local function convert(_options, defaultDistance)
    local options = {}

    for i = 1, #_options do
        local option = _options[i]

        options[#options + 1] = {
            name = option.name,
            label = option.label,
            icon = option.icon,
            groups = option.groups or nil,
            distance = option.distance or defaultDistance,
            canInteract = option.cn,
            onSelect = option.fn
        }
    end

    return options
end

function Target.addLocalEntity(entity, _options)
    vrTarget:addLocalEntity(entity, convert(_options, 3))
end

function Target.removeLocalEntity(entity)
    vrTarget:removeLocalEntity(entity)
end

function Target.addGlobalVehicle(_options)
    vrTarget:addGlobalVehicle(convert(_options))
end

function Target.addModel(models, _options)
    vrTarget:addModel(models, convert(_options))
end

function Target.addBoxZone(coords, _options)
    vrTarget:addBoxZone({ coords = coords, options = convert(_options) })
end

function Target.addGlobalPlayer(_options)
    vrTarget:addGlobalPlayer(convert(_options))
end
