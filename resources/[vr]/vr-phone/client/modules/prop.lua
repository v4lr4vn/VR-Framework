-- The phone in the player's hand, and the arm animation that goes with each fold state.
local Prop = {}
Phone.Prop = Prop

local cfg = Config.Prop
local entity = nil

local function animSet()
    return IsPedInAnyVehicle(PlayerPedId(), false) and cfg.anims.vehicle or cfg.anims.foot
end

local function play(anim)
    if not anim then return end
    local ok, err = pcall(lib.requestAnimDict, anim.dict, 3000)
    if not ok then
        print(('^3[vr-phone] animation %s did not load: %s^0'):format(anim.dict, tostring(err)))
        return
    end
    TaskPlayAnim(PlayerPedId(), anim.dict, anim.name, 3.0, 3.0, -1, anim.flag or 49, 0.0, false, false, false)
    RemoveAnimDict(anim.dict)
end

local function attach()
    if entity and DoesEntityExist(entity) then return true end

    local ok, hash = pcall(lib.requestModel, cfg.model, 5000)
    if not ok then
        print(('^3[vr-phone] phone model %s did not load: %s^0'):format(cfg.model, tostring(hash)))
        return false
    end

    local ped = PlayerPedId()
    local at = GetEntityCoords(ped)
    entity = CreateObject(hash, at.x, at.y, at.z + 0.2, true, true, false)
    SetModelAsNoLongerNeeded(hash)
    if not entity or entity == 0 then
        entity = nil
        return false
    end

    SetEntityCollision(entity, false, false)
    AttachEntityToEntity(
        entity, ped, GetPedBoneIndex(ped, cfg.bone),
        cfg.offset.x, cfg.offset.y, cfg.offset.z,
        cfg.rotation.x, cfg.rotation.y, cfg.rotation.z,
        true, true, false, true, 1, true
    )
    return true
end

local function remove()
    if entity and DoesEntityExist(entity) then
        SetEntityAsMissionEntity(entity, true, true)
        DeleteEntity(entity)
    end
    entity = nil
end

-- The phone is held in front of you, whatever the fold state. It only goes to your ear during a call.
local function loop()
    local set = animSet()
    return Phone.State.call and set.call or set.hold
end

-- Takes the phone out: prop in hand, short intro, then the hold loop.
function Prop.start()
    attach()
    play(animSet().intro)
    SetTimeout(450, function()
        if Phone.State.open then play(loop()) end
    end)
end

-- The front camera: arm out with the phone in the hand. Without it (or if the animation does not load) the normal hold stays.
function Prop.selfie(on)
    if not (entity and DoesEntityExist(entity)) then return end
    local ped = PlayerPedId()
    local use = on and animSet().selfie ~= nil
    local at = use and (cfg.selfie or cfg) or cfg
    AttachEntityToEntity(
        entity, ped, GetPedBoneIndex(ped, cfg.bone),
        at.offset.x, at.offset.y, at.offset.z,
        at.rotation.x, at.rotation.y, at.rotation.z,
        true, true, false, true, 1, true
    )
    play(use and animSet().selfie or loop())
end

-- The phone object in the hand (for the camera, which hides it from the player's own view).
function Prop.entity()
    if entity and DoesEntityExist(entity) then return entity end
    return nil
end

-- A call became active while the screen is closed: the phone comes out and goes to the ear, but the screen stays away.
function Prop.hold()
    if attach() then play(loop()) end
end

-- A call started or ended while the phone is out: switch between the ear and the front hold.
function Prop.refresh()
    if not (entity and DoesEntityExist(entity)) then return end
    play(loop())
end

-- Puts the phone away. With the outro the prop stays for a moment while the arm lowers.
function Prop.stop(withOutro)
    if not entity then return end
    if withOutro then
        play(animSet().outro)
        SetTimeout(500, function()
            ClearPedSecondaryTask(PlayerPedId())
            remove()
        end)
    else
        ClearPedSecondaryTask(PlayerPedId())
        remove()
    end
end
