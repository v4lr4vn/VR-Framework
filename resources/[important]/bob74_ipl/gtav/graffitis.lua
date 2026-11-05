exports('GetGraffitisObject', function()
    return Graffitis
end)

Graffitis = {
    ipl = {
        "ch3_rd2_bishopschickengraffiti",
        "cs5_04_mazebillboardgraffiti",
        "cs5_roads_ronoilgraffiti"
    },
    Enable = function(state)
        EnableIpl(Graffitis.ipl, state)
    end
}
