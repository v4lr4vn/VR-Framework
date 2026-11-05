exports('GetDrugWarsTrainCrashObject', function()
    return DrugWarsTrainCrash
end)

DrugWarsTrainCrash = {
    ipl = "xm3_train_crash",

    Enable = function(state)
        EnableIpl(DrugWarsTrainCrash.ipl, state)
    end
}
