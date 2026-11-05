return function(ped, animDictionary, animationName, blendInSpeed, blendOutSpeed, duration, animFlags, startPhase, phaseControlled, controlFlags, overrideCloneUpdate)
    lib.requestAnimDict(animDictionary)
    TaskPlayAnim(ped, animDictionary, animationName, blendInSpeed or 8.0, blendOutSpeed or -8.0, duration or -1, animFlags or 0, startPhase or 0.0, phaseControlled or false, controlFlags or 0, overrideCloneUpdate or false)
    RemoveAnimDict(animDictionary)
end
