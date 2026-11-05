exports('GetTrevorsTrailerObject', function()
    return TrevorsTrailer
end)

TrevorsTrailer = {
    interiorId = 2562,

    Interior = {
        tidy = "trevorstrailertidy",
        trash = "TrevorsTrailerTrash",

        Set = function(interior)
            TrevorsTrailer.Interior.Clear()

            EnableIpl(interior, true)
        end,
        Clear = function()
            EnableIpl({
                TrevorsTrailer.Interior.tidy,
                TrevorsTrailer.Interior.trash
            }, false)
        end
    },
    Details = {
        copHelmet = "V_26_Trevor_Helmet3",
        briefcase = "V_24_Trevor_Briefcase3",
        michaelStuff = "V_26_Michael_Stay3",

        Enable = function(details, state, refresh)
            SetIplPropState(TrevorsTrailer.interiorId, details, state, refresh)
        end
    },

    LoadDefault = function()
        TrevorsTrailer.Interior.Set(TrevorsTrailer.Interior.trash)
        TrevorsTrailer.Details.Enable(TrevorsTrailer.Details.copHelmet, false, false)
        TrevorsTrailer.Details.Enable(TrevorsTrailer.Details.briefcase, false, false)
        TrevorsTrailer.Details.Enable(TrevorsTrailer.Details.michaelStuff, false, false)

        RefreshInterior(TrevorsTrailer.interiorId)
    end
}
