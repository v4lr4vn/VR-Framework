if type(MySQL) == 'table' and MySQL.query then return MySQL end

local function attempt(res)
    if GetResourceState(res) == 'missing' or GetResourceState(res) == 'unknown' then return false end
    local code = LoadResourceFile(res, 'lib/MySQL.lua')
    if not code then return false end
    local fn, err = load(code, ('@@%s/lib/MySQL.lua'):format(res))
    if not fn then error(('[vr-bridge] %s'):format(err), 0) end
    fn()
    return type(MySQL) == 'table'
end

local forced = GetConvar('vr_bridge:database', '')
if forced ~= '' and forced ~= 'auto' and attempt(forced) then return MySQL end
for _, res in ipairs({ 'vr-mysql', 'oxmysql' }) do
    if attempt(res) then return MySQL end
end
error('[vr-bridge] no MySQL resource found (vr-mysql or oxmysql)', 0)
