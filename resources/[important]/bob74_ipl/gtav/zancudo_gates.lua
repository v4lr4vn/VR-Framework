exports('GetZancudoGatesObject', function()
    return ZancudoGates
end)

ZancudoGates = {
    Gates = {
        Open = function()
            EnableIpl("CS3_07_MPGates", false)
        end,
        Close = function()
            EnableIpl("CS3_07_MPGates", true)
        end,
    },

    LoadDefault = function()
        ZancudoGates.Gates.Open()
    end
}
