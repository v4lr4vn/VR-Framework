Banks = { list = {}, loaded = false }

local byName = {}

local function encode(bank)
    local copy = {}
    for k, v in pairs(bank) do
        if k ~= 'id' and k ~= 'name' then copy[k] = v end
    end
    return json.encode(copy)
end

function Banks.get(id)
    return Banks.list[tonumber(id) or -1]
end

function Banks.find(name)
    return byName[name]
end

function Banks.all()
    local out = {}
    for _, bank in pairs(Banks.list) do out[#out + 1] = bank end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function Banks.save(bank)
    MySQL.query('UPDATE vr_bankheist_banks SET data = ? WHERE id = ?', { encode(bank), bank.id })
end

function Banks.create(name, pos)
    if type(name) ~= 'string' then return nil, 'bad_name' end
    name = name:gsub('[^%w_%-]', ''):sub(1, 50):lower()
    if #name < 2 then return nil, 'bad_name' end
    if byName[name] then return nil, 'exists' end
    local bank = BH.newBank(name, pos)
    local id = MySQL.insert.await('INSERT INTO vr_bankheist_banks (name, data) VALUES (?, ?)', { name, encode(bank) })
    if not id then return nil, 'failed' end
    bank.id = id
    bank.name = name
    Banks.list[id] = bank
    byName[name] = bank
    return bank
end

function Banks.delete(bank)
    MySQL.query('DELETE FROM vr_bankheist_banks WHERE id = ?', { bank.id })
    MySQL.query('DELETE FROM vr_bankheist_state WHERE bank = ?', { bank.name })
    Banks.list[bank.id] = nil
    byName[bank.name] = nil
end

function Banks.view(bank)
    local out = {}
    for k, v in pairs(bank) do out[k] = v end
    return out
end

function Banks.publicList()
    local out = {}
    for _, bank in ipairs(Banks.all()) do out[#out + 1] = Banks.view(bank) end
    return out
end

function Banks.push(to)
    TriggerClientEvent('vr-bankheist:client:banks', to or -1, Banks.publicList())
end

Db.onReady(function()
    local rows = MySQL.query.await('SELECT id, name, data FROM vr_bankheist_banks') or {}
    for _, r in ipairs(rows) do
        local ok, raw = pcall(json.decode, r.data)
        local bank = ok and BH.sanitiseBank(r.name, raw) or nil
        if bank then
            bank.id = r.id
            bank.name = r.name
            Banks.list[bank.id] = bank
            byName[bank.name] = bank
        else
            print(('^1[vr-bankheist] bank %s could not be loaded^0'):format(tostring(r.name)))
        end
    end
    Banks.loaded = true
    TriggerEvent('vr-bankheist:loaded')
    Banks.push()
end)

lib.callback.register('vr-bankheist:getBanks', function()
    local deadline = GetGameTimer() + 15000
    while not Banks.loaded and GetGameTimer() < deadline do Wait(100) end
    return Banks.publicList()
end)

lib.callback.register('vr-bankheist:isAdmin', function(src)
    return Core.admin(src)
end)

Bridge.on('playerLoaded', function(src)
    if Banks.loaded then Banks.push(src) end
end)
