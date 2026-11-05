return function(audioBank, timeout)
    return lib.waitFor(function()
        if RequestScriptAudioBank(audioBank, false) then return audioBank end
    end, ("failed to load audiobank '%s'"):format(tostring(audioBank)), timeout or 30000)
end
