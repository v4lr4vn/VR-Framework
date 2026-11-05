Phone.DB = { ready = false }

local function install()
    local raw = LoadResourceFile(GetCurrentResourceName(), 'sql/install.sql')
    if not raw then
        print('^1[vr-phone] sql/install.sql is missing, tables were not created^0')
        return false
    end

    raw = raw:gsub('%-%-[^\n]*', '')
    local count = 0
    for statement in raw:gmatch('([^;]+);') do
        local sql = statement:gsub('^%s+', '')
        sql = sql:gsub('%s+$', '')
        if sql ~= '' then
            MySQL.query.await(sql)
            count = count + 1
        end
    end
    Phone.debug(('database ready, %d statements ran'):format(count))
    return true
end

function Phone.DB.waitReady()
    while not Phone.DB.ready do Wait(50) end
end

MySQL.ready(function()
    if install() then
        Phone.DB.ready = true
        TriggerEvent('vr-phone:server:ready')
    end
end)
