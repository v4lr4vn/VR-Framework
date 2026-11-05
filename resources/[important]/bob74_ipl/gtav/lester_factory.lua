exports('GetLesterFactoryObject', function()
    return LesterFactory
end)

LesterFactory = {
    interiorId = 92674,

    Details = {
        bluePrint = "V_53_Agency_Blueprint",
        bag = "V_35_KitBag",
        fireMan = "V_35_Fireman",
        armour = "V_35_Body_Armour",
        gasMask = "Jewel_Gasmasks",
        janitorStuff = "v_53_agency _overalls",

        Enable = function(details, state, refresh)
            SetIplPropState(LesterFactory.interiorId, details, state, refresh)
        end
    },

    LoadDefault = function()
        LesterFactory.Details.Enable(LesterFactory.Details.bluePrint, false)
        LesterFactory.Details.Enable(LesterFactory.Details.bag, false)
        LesterFactory.Details.Enable(LesterFactory.Details.fireMan, false)
        LesterFactory.Details.Enable(LesterFactory.Details.armour, false)
        LesterFactory.Details.Enable(LesterFactory.Details.gasMask, false)
        LesterFactory.Details.Enable(LesterFactory.Details.janitorStuff, false)

        RefreshInterior(LesterFactory.interiorId)
    end
}
