exports("GetMoneyOffice", function()
    return MoneyOffice
end)

MoneyOffice = {
    interiorId = 298753,

    Ipl = {
        Exterior = {
            ipl = {
                "m25_1_helitours",
                "m25_1_smokeonthewater"
            },

            Load = function()
                EnableIpl(MoneyOffice.Ipl.Exterior.ipl, true)
            end,
            Remove = function()
                EnableIpl(MoneyOffice.Ipl.Exterior.ipl, false)
            end
        }
    },

    Style = {
        heli = {
            "set_heli",
            "set_heli_tint"
        },
        smoke = {
            "set_smoke",
            "set_smoke_tint"
        },

        Set = function(style, refresh)
            MoneyOffice.Style.Clear(refresh)

            SetIplPropState(MoneyOffice.interiorId, style, true, refresh)
        end,
        Clear = function(refresh)
            SetIplPropState(MoneyOffice.interiorId, {
                MoneyOffice.Style.heli,
                MoneyOffice.Style.smoke
            }, false, refresh)
        end
    },

    LoadDefault = function()
        MoneyOffice.Ipl.Exterior.Load()

        MoneyOffice.Style.Set(MoneyOffice.Style.heli, false)

        RefreshInterior(MoneyOffice.interiorId)
    end
}