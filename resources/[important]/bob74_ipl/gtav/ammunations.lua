exports('GetAmmunationsObject', function()
    return Ammunations
end)

Ammunations = {
    ammunationsId = {
        140289,
        153857,
        168193,
        164609,
        176385,
        175617,
        200961,
        180481,
        178689
    },
    gunclubsId = {
        137729,
        248065
    },

    Details = {
        hooks = "GunStoreHooks",
        hooksClub = "GunClubWallHooks",

        Enable = function(details, state, refresh)
            if details == Ammunations.Details.hooks then
                SetIplPropState(Ammunations.ammunationsId, details, state, refresh)
            elseif details == Ammunations.Details.hooksClub then
                SetIplPropState(Ammunations.gunclubsId, details, state, refresh)
            end
        end
    },

    LoadDefault = function()
        Ammunations.Details.Enable(Ammunations.Details.hooks, true, true)
        Ammunations.Details.Enable(Ammunations.Details.hooksClub, true, true)
    end
}
