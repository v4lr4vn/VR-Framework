exports('GetGunrunningBunkerObject', function()
    return GunrunningBunker
end)

GunrunningBunker = {
    interiorId = 258561,

    Ipl = {
        Interior = {
            ipl = "gr_grdlc_interior_placement_interior_1_grdlc_int_02_milo_",

            Load = function()
                EnableIpl(GunrunningBunker.Ipl.Interior.ipl, true)
            end,
            Remove = function()
                EnableIpl(GunrunningBunker.Ipl.Interior.ipl, false)
            end
        },
        Exterior = {
            ipl = {
                "gr_case0_bunkerclosed",
                "gr_case1_bunkerclosed",
                "gr_case2_bunkerclosed",
                "gr_case3_bunkerclosed",
                "gr_case4_bunkerclosed",
                "gr_case5_bunkerclosed",
                "gr_case6_bunkerclosed",
                "gr_case7_bunkerclosed",
                "gr_case9_bunkerclosed",
                "gr_case10_bunkerclosed",
                "gr_case11_bunkerclosed"
            },

            Load = function()
                EnableIpl(GunrunningBunker.Ipl.Exterior.ipl, true)
            end,
            Remove = function()
                EnableIpl(GunrunningBunker.Ipl.Exterior.ipl, false)
            end
        }
    },
    Style = {
        default = "Bunker_Style_A",
        blue = "Bunker_Style_B",
        yellow = "Bunker_Style_C",

        Set = function(style, refresh)
            GunrunningBunker.Style.Clear(false)

            SetIplPropState(GunrunningBunker.interiorId, style, true, refresh)
        end,
        Clear = function(refresh)
            SetIplPropState(GunrunningBunker.interiorId, {
                GunrunningBunker.Style.default,
                GunrunningBunker.Style.blue,
                GunrunningBunker.Style.yellow
            }, false, refresh)
        end
    },
    Tier = {
        default = "standard_bunker_set",
        upgrade = "upgrade_bunker_set",

        Set = function(tier, refresh)
            GunrunningBunker.Tier.Clear(false)

            SetIplPropState(GunrunningBunker.interiorId, tier, true, refresh)
        end,
        Clear = function(refresh)
            SetIplPropState(GunrunningBunker.interiorId, {
                GunrunningBunker.Tier.default,
                GunrunningBunker.Tier.upgrade
            }, false, refresh)
        end
    },
    Security = {
        noEntryGate = "",
        default = "standard_security_set",
        upgrade = "security_upgrade",

        Set = function(security, refresh)
            GunrunningBunker.Security.Clear(false)

            if security ~= "" then
                SetIplPropState(GunrunningBunker.interiorId, security, true, refresh)
            else
                if refresh then
                    RefreshInterior(GunrunningBunker.interiorId)
                end
            end
        end,
        Clear = function(refresh)
            SetIplPropState(GunrunningBunker.interiorId, {
                GunrunningBunker.Security.default,
                GunrunningBunker.Security.upgrade
            }, false, refresh)
        end
    },
    Details = {
        office = "Office_Upgrade_set",
        officeLocked = "Office_blocker_set",
        locker = "gun_locker_upgrade",
        rangeLights = "gun_range_lights",
        rangeWall = "gun_wall_blocker",
        rangeLocked = "gun_range_blocker_set",
        schematics = "Gun_schematic_set",

        Enable = function(details, state, refresh)
            SetIplPropState(GunrunningBunker.interiorId, details, state, refresh)
        end
    },

    LoadDefault = function()
        GunrunningBunker.Ipl.Interior.Load()
        GunrunningBunker.Ipl.Exterior.Load()

        GunrunningBunker.Style.Set(GunrunningBunker.Style.default)
        GunrunningBunker.Tier.Set(GunrunningBunker.Tier.default)
        GunrunningBunker.Security.Set(GunrunningBunker.Security.default)

        GunrunningBunker.Details.Enable(GunrunningBunker.Details.office, true)
        GunrunningBunker.Details.Enable(GunrunningBunker.Details.officeLocked, false)
        GunrunningBunker.Details.Enable(GunrunningBunker.Details.locker, true)
        GunrunningBunker.Details.Enable(GunrunningBunker.Details.rangeLights, true)
        GunrunningBunker.Details.Enable(GunrunningBunker.Details.rangeWall, false)
        GunrunningBunker.Details.Enable(GunrunningBunker.Details.rangeLocked, false)
        GunrunningBunker.Details.Enable(GunrunningBunker.Details.schematics, false)

        RefreshInterior(GunrunningBunker.interiorId)
    end
}
