exports('GetUFOObject', function()
    return UFO
end)

UFO = {
    Hippie = {
        ipl = "ufo",

        Enable = function(state)
            EnableIpl(UFO.Hippie.ipl, state)
        end
    },
    Chiliad = {
        ipl = "ufo_eye",

        Enable = function(state)
            EnableIpl(UFO.Chiliad.ipl, state)
        end
    },
    Zancudo = {
        ipl = "ufo_lod",

        Enable = function(state)
            EnableIpl(UFO.Zancudo.ipl, state)
        end
    }
}
