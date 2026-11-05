exports("GetMoneyConstruction", function()
    return MoneyConstruction
end)

MoneyConstruction = {
    Vinewood = {
        ipl = "m25_1_ch2_04_construction",

        Enable = function(state)
            EnableIpl(MoneyConstruction.Vinewood.ipl, state)
        end
    },

    Rockford = {
        ipl = "m25_1_cs1_06e_construction",

        Enable = function(state)
            EnableIpl(MoneyConstruction.Rockford.ipl, state)
        end
    },

    LoadDefault = function()
        MoneyConstruction.Vinewood.Enable(true)
        MoneyConstruction.Rockford.Enable(true)
    end
}