exports("GetAgentsHangarDoor", function()
    return AgentsHangarDoor
end)

AgentsHangarDoor = {
    Ipl = {
        ipl = "m24_2_prop_m42_hangerdoor_02a",

        Load = function()
            EnableIpl(AgentsHangarDoor.Ipl.ipl, true)
        end,
        Remove = function()
            EnableIpl(AgentsHangarDoor.Ipl.ipl, false)
        end
    },

    LoadDefault = function()
        AgentsHangarDoor.Ipl.Load()
    end
}
