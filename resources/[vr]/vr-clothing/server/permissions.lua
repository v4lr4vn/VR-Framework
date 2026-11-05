lib.callback.register("vr-clothing:server:GetPlayerAces", function()
    local src = source
    local allowedAces = {}

    if Config.Aces then
        for i = 1, #Config.Aces do
            local ace = Config.Aces[i]
            if IsPlayerAceAllowed(src, ace) then
                allowedAces[#allowedAces + 1] = ace
            end
        end
    end

    return allowedAces
end)
