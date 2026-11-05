CU = {}

function CU.clean(text, max)
    if type(text) ~= 'string' then return nil end
    text = text:gsub('[%c]', ' '):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if text == '' then return nil end
    if max and #text > max then text = text:sub(1, max):gsub('%s+$', '') end
    return text
end

function CU.key(text)
    return (tostring(text or ''):lower():gsub('[^%w]', ''))
end
