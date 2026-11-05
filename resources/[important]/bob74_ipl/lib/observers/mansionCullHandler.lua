local _scanDelay = 1000

local _mansions = {
    {
        coords = vector3(543.852, 712.754, 201.0),
        ipl = "apa_ch2_04_mansion_generic"
    },
    {
        coords = vector3(-1630.434, 470.852, 128.0),
        ipl = "hei_ch1_06e_mansion_generic"
    },
    {
        coords = vector3(-2601.712, 1874.826, 166.0),
        ipl = "hei_ch1_09_mansion_generic"
    }
}

CreateThread(function()
    if GetGameBuildNumber() < 3717 then
        return
    end

    while true do
        local coords = GetEntityCoords(PlayerPedId())

        for _, mansion in ipairs(_mansions) do
            local close = #(coords - mansion.coords) < 200

            EnableIpl(mansion.ipl, not close)
        end

        Wait(_scanDelay)
    end
end)

