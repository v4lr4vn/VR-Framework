return function(weaponType, timeout, weaponResourceFlags, extraWeaponComponentFlags)
    if type(weaponType) ~= 'number' then weaponType = joaat(weaponType) end
    if HasWeaponAssetLoaded(weaponType) then return weaponType end
    return lib.streamingRequest(RequestWeaponAsset, HasWeaponAssetLoaded, 'weaponHash', weaponType, timeout, weaponResourceFlags or 31, extraWeaponComponentFlags or 0)
end
