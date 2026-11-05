KU = {}

function KU.plate(p)
    if type(p) ~= 'string' then return nil end
    p = p:upper():gsub('^%s+', ''):gsub('%s+$', '')
    if p == '' then return nil end
    return p
end
