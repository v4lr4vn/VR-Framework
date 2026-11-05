Catalog = {}

Catalog.tabs = {
    { id = 'emotes', label = 'Emotes', icon = 'person', tables = { 'Emotes' } },
    { id = 'dances', label = 'Dances', icon = 'music', tables = { 'Dances' } },
    { id = 'props', label = 'Props', icon = 'mug-hot', tables = { 'PropEmotes' } },
    { id = 'shared', label = 'Shared', icon = 'user-group', tables = { 'Shared' } },
    { id = 'custom', label = 'Custom', icon = 'wand-magic-sparkles', tables = { 'White2do', 'White3ro', 'White5to' } },
    { id = 'animals', label = 'Animals', icon = 'paw', tables = { 'AnimalEmotes' } },
}

Catalog.commandOrder = { 'Emotes', 'Dances', 'White2do', 'White3ro', 'White5to', 'AnimalEmotes', 'Exits', 'PropEmotes' }

Catalog.playable = {
    Emotes = true, Dances = true, PropEmotes = true, Shared = true, White2do = true, White3ro = true,
    White5to = true, AnimalEmotes = true, Exits = true,
}

local adultWords = { 'masturbat', 'blowjob', 'blow job', 'missionary', 'doggystyle', 'cowgirl', 'wank', 'jerk off', 'jerkoff', 'porn', 'show boobs', 'showboobs', 'hump' }

function Catalog.isAdult(entry, key)
    if type(entry) ~= 'table' then return false end
    if entry.AdultAnimation then return true end
    local dict = type(entry[1]) == 'string' and entry[1]:lower() or ''
    local anim = type(entry[2]) == 'string' and entry[2]:lower() or ''
    if dict:find('erotica', 1, true) or dict:find('pimpsex', 1, true) or dict:find('jerking_off', 1, true) or anim:find('shag', 1, true) then return true end
    local text = ((type(entry[3]) == 'string' and entry[3] or '') .. ' ' .. (type(key) == 'string' and key or '')):lower()
    if text:find('%f[%a]sex%f[^%a]') or text:find('%f[%a]sexo') then return true end
    for _, word in ipairs(adultWords) do
        if text:find(word, 1, true) then return true end
    end
    return false
end

function Catalog.get(id)
    if type(id) ~= 'string' then return nil end
    local tbl, key = id:match('^(%w+):(.+)$')
    if not tbl or not Catalog.playable[tbl] or not RP[tbl] then return nil end
    local entry = RP[tbl][key]
    if not entry then return nil end
    return entry, tbl, key
end

function Catalog.find(name)
    if type(name) ~= 'string' then return nil end
    for _, tbl in ipairs(Catalog.commandOrder) do
        local entry = RP[tbl] and RP[tbl][name]
        if entry then return entry, tbl, name end
    end
end

function Catalog.allowed(entry, tbl, key)
    if not entry then return false end
    if Config.AdultEmotesDisabled and Catalog.isAdult(entry, key) then return false, 'adult' end
    if tbl == 'AnimalEmotes' and not Config.AnimalEmotesEnabled then return false, 'animal' end
    if tbl == 'Shared' and not Config.SharedEmotesEnabled then return false, 'shared' end
    return true
end

function Catalog.partner(tbl, key)
    local entry = RP[tbl] and RP[tbl][key]
    if not entry then return nil end
    local other = entry[4]
    if type(other) == 'string' and RP[tbl][other] then return other end
    return key
end
