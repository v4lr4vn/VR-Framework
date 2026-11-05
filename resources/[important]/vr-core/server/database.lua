local Config = VRCore.Config
local resourceName = GetCurrentResourceName()

CoreDB = {
    connected = MySQL.ready == nil,
    tablesOk = MySQL.ready == nil,
}

local schemaFiles = { 'sql/vrcore.sql', 'sql/addons.sql' }

local function installSchema()
    for _, file in ipairs(schemaFiles) do
        local sql = LoadResourceFile(resourceName, file)
        if not sql then
            VRCore.ShowError(resourceName, file .. ' is missing - cannot auto-install its tables')
        else
            sql = sql:gsub('%-%-[^\n]*', '')
            for statement in sql:gmatch('[^;]+') do
                statement = statement:match('^%s*(.-)%s*$')
                if statement:upper():find('^CREATE TABLE IF NOT EXISTS') then
                    MySQL.query.await(statement)
                end
            end
        end
    end
end

if MySQL.ready then
    MySQL.ready(function()
        CoreDB.connected = true
        if Config.Database.AutoInstall then
            local ok, err = pcall(installSchema)
            if not ok then VRCore.ShowError(resourceName, 'schema auto-install failed: ' .. tostring(err)) end
        end
        local found = MySQL.scalar.await(
            'SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name IN (?, ?)',
            { 'vr_players', 'vr_bans' })
        CoreDB.tablesOk = tonumber(found) == 2
        if not CoreDB.tablesOk then
            VRCore.ShowError(resourceName, 'vr_players / vr_bans not found in the connected database - import sql/vrcore.sql')
        end
    end)
end

function CoreDB.ExistingTables(names)
    if #names == 0 then return {} end
    local rows = MySQL.query.await(
        ('SELECT table_name AS name FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name IN (%s)')
        :format(('?,'):rep(#names):sub(1, -2)), names) or {}
    local found = {}
    for i = 1, #rows do found[rows[i].name] = true end
    return found
end
