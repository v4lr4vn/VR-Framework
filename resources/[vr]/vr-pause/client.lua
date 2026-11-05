local Replacer = {
    ["TITLE"] = "FE_THDR_GTAO",
    ["MAP"] = "PM_SCR_MAP",
    ["GAME"] = "PM_SCR_GAM",
    ["LEAVE"] = "PM_PANE_LEAVE",
    ["QUIT"] = "PM_PANE_QUIT",
    ["INFO"] = "PM_SCR_INF",
    ["STATS"] = "PM_SCR_STA",
    ["SETTINGS"] = "PM_SCR_SET",
    ["GALLERY"] = "PM_SCR_GAL",
    ["KEYBIND"] = "PM_PANE_CFX",
    ["EDITOR"] = "PM_SCR_RPL",
}

CreateThread(function()
    for key, value in pairs(Config.Header) do
        if Replacer[key] then
            AddTextEntry(Replacer[key], value)
        end
    end

    RequestStreamedTextureDict('ps_pause', true)

    ReplaceHudColourWithRgba( 116 , Config.RGBA.LINE["RED"] , Config.RGBA.LINE["GREEN"] , Config.RGBA.LINE["BLUE"] , Config.RGBA.LINE["ALPHA"])
    ReplaceHudColourWithRgba( 117 , Config.RGBA.STYLE["RED"] , Config.RGBA.STYLE["GREEN"] , Config.RGBA.STYLE["BLUE"] , Config.RGBA.STYLE["ALPHA"])
    ReplaceHudColourWithRgba( 142 , Config.RGBA.WAYPOINT["RED"] , Config.RGBA.WAYPOINT["GREEN"] , Config.RGBA.WAYPOINT["BLUE"] , Config.RGBA.WAYPOINT["ALPHA"])

    while not HasStreamedTextureDictLoaded("ps_pause") do
        Wait(100)
    end
    while true do
        if IsPauseMenuActive() then
            if not HasStreamedTextureDictLoaded("ps_pause") then RequestStreamedTextureDict('ps_pause', true) end
            SetScriptGfxDrawBehindPausemenu(true)
            DrawSprite("ps_pause", Config.Background, 0.5, 0.5, 1.0, 1.0, 0, 255, 255, 255, Config.Opacity)
            BeginScaleformMovieMethodOnFrontendHeader("SET_HEADING_DETAILS")
            PushScaleformMovieFunctionParameterString(Config.Header['SERVER_NAME'])
            PushScaleformMovieFunctionParameterString(Config.Header['SERVER_TEXT'])
            PushScaleformMovieFunctionParameterString(Config.Header['SERVER_DISCORD'])
            ScaleformMovieMethodAddParamBool(false)
            EndScaleformMovieMethod()
            Wait(0)
        else
            Wait(150)
        end
    end
end)
