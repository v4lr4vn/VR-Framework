local function hideText()
    SendNUIMessage({ action = 'HIDE_TEXT' })
end

local function drawText(text, position)
    SendNUIMessage({ action = 'DRAW_TEXT', data = { text = text, position = type(position) == 'string' and position or 'left' } })
end

local function changeText(text, position)
    SendNUIMessage({ action = 'CHANGE_TEXT', data = { text = text, position = type(position) == 'string' and position or 'left' } })
end

local function keyPressed()
    SendNUIMessage({ action = 'KEY_PRESSED' })
    SetTimeout(500, hideText)
end

RegisterNetEvent('vr-core:client:DrawText', drawText)
RegisterNetEvent('vr-core:client:ChangeText', changeText)
RegisterNetEvent('vr-core:client:HideText', hideText)
RegisterNetEvent('vr-core:client:KeyPressed', keyPressed)

CoreExport('DrawText', drawText)
CoreExport('ChangeText', changeText)
CoreExport('HideText', hideText)
CoreExport('KeyPressed', keyPressed)
