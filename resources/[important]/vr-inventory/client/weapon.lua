local U = InvUtil

Weapon = {}

local GROUP_MELEE = joaat('GROUP_MELEE')
local GROUP_PISTOL = joaat('GROUP_PISTOL')
local GROUP_STUNGUN = joaat('GROUP_STUNGUN')
GROUP_PETROLCAN = joaat('GROUP_PETROLCAN')
GROUP_FIREEXTINGUISHER = joaat('GROUP_FIREEXTINGUISHER')

local anims = {
    [GROUP_MELEE] = { 'melee@holster', 'unholster', 200, 'melee@holster', 'holster', 600 },
    [GROUP_PISTOL] = { 'reaction@intimidation@cop@unarmed', 'intro', 400, 'reaction@intimidation@cop@unarmed', 'outro', 450 },
}
anims[GROUP_STUNGUN] = anims[GROUP_PISTOL]

local function isCycle(vehicle)
    local class = GetVehicleClass(vehicle)
    return class == 8 or class == 13
end

local function pickAnim(data, hash)
    local anim = data.anim or anims[GetWeapontypeGroup(hash)]
    if anim == anims[GROUP_PISTOL] and not client.hasGroup(shared.police) then anim = nil end
    return anim
end

function Weapon.Equip(item, data, noWeaponAnim)
    local ped = cache.ped
    local coords = GetEntityCoords(ped, true)
    local sleep

    if client.weaponanims and not noWeaponAnim and not (cache.vehicle and isCycle(cache.vehicle)) then
        local anim = pickAnim(data, data.hash)
        sleep = anim and anim[3] or 1200
        Utils.PlayAnimAdvanced(sleep, anim and anim[1] or 'reaction@intimidation@1h', anim and anim[2] or 'intro', coords.x, coords.y, coords.z, 0, 0, GetEntityHeading(ped), 8.0, 3.0, sleep * 2, 50, 0.1)
    end

    item.hash = data.hash
    item.ammo = data.ammoname
    item.melee = GetWeaponDamageType(data.hash) == 2 and 0 or nil
    item.timer = 0
    item.throwable = data.throwable
    item.group = GetWeapontypeGroup(item.hash)

    GiveWeaponToPed(ped, data.hash, 0, false, true)

    if item.metadata.tint then SetPedWeaponTintIndex(ped, data.hash, item.metadata.tint) end

    if type(item.metadata.components) == 'table' then
        for i = 1, #item.metadata.components do
            local component = Items[item.metadata.components[i]]
            local hashes = component and component.client and component.client.component
            if hashes then
                for v = 1, #hashes do
                    local hash = hashes[v]
                    if DoesWeaponTakeWeaponComponent(data.hash, hash) and not HasPedGotWeaponComponent(ped, data.hash, hash) then
                        GiveWeaponComponentToPed(ped, data.hash, hash)
                    end
                end
            end
        end
    end

    if item.metadata.specialAmmo then
        local clip = ('%s_CLIP'):format(data.model:gsub('WEAPON_', 'COMPONENT_'))
        local special = ('%s_%s'):format(clip, tostring(item.metadata.specialAmmo):upper())
        if DoesWeaponTakeWeaponComponent(data.hash, joaat(special)) then GiveWeaponComponentToPed(ped, data.hash, joaat(special)) end
    end

    local ammo = item.metadata.ammo or (item.throwable and 1) or 0

    SetCurrentPedWeapon(ped, data.hash, true)
    SetPedCurrentWeaponVisible(ped, true, false, false, false)
    SetWeaponsNoAutoswap(true)
    SetPedAmmo(ped, data.hash, ammo)
    SetTimeout(0, function() RefillAmmoInstantly(ped) end)

    if item.group == GROUP_PETROLCAN or item.group == GROUP_FIREEXTINGUISHER then
        item.metadata.ammo = item.metadata.durability
        SetPedInfiniteAmmo(ped, true, data.hash)
    end

    U.fire('currentWeapon', item)

    if client.weaponnotify then Utils.ItemNotify({ item, 'ui_equipped' }) end

    return item, sleep
end

function Weapon.Disarm(currentWeapon, noAnim)
    if currentWeapon and currentWeapon.timer then
        currentWeapon.timer = nil
        TriggerServerEvent('vr-inventory:updateWeapon')
        SetPedAmmo(cache.ped, currentWeapon.hash, 0)

        if client.weaponanims and not noAnim and not (cache.vehicle and isCycle(cache.vehicle)) then
            ClearPedSecondaryTask(cache.ped)
            local item = Items[currentWeapon.name] or {}
            local coords = GetEntityCoords(cache.ped, true)
            local anim = pickAnim(item, currentWeapon.hash)
            local sleep = anim and anim[6] or 1400
            Utils.PlayAnimAdvanced(sleep, anim and anim[4] or 'reaction@intimidation@1h', anim and anim[5] or 'outro', coords.x, coords.y, coords.z, 0, 0, GetEntityHeading(cache.ped), 8.0, 3.0, sleep, 50, 0)
        end

        if client.weaponnotify then Utils.ItemNotify({ currentWeapon, 'ui_holstered' }) end
        U.fire('currentWeapon')
    end

    Utils.WeaponWheel()
    RemoveAllPedWeapons(cache.ped, true)

    if client.parachute then
        local chute = joaat('GADGET_PARACHUTE')
        GiveWeaponToPed(cache.ped, chute, 0, true, false)
        SetPedGadget(cache.ped, chute, true)
        SetPlayerParachuteTintIndex(PlayerData.id, client.parachute[2] or -1)
    end
end

function Weapon.ClearAll(currentWeapon)
    Weapon.Disarm(currentWeapon)
end

Utils.Disarm = Weapon.Disarm
Utils.ClearWeapons = Weapon.ClearAll
