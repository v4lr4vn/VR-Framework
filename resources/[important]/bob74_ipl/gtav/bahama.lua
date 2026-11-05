exports('GetBahamaMamasObject', function()
    return BahamaMamas
end)

BahamaMamas = {
    ipl = "hei_sm_16_interior_v_bahama_milo_",

    Enable = function(state)
        EnableIpl(BahamaMamas.ipl, state)
    end
}
