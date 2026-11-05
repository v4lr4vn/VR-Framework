-- The staff office: clock in, wages, the business account, staff and ranks.

local MAIN = 'vr-restaurant:office'

local function act(id, action, a, b)
    local ok, data, extra = Rn.call('act', id, action, a, b)
    if not ok then
        Rn.fail(data, extra)
        return false
    end
    return true, data
end

local function permLabel(id)
    for _, p in ipairs(Config.Perms) do
        if p.id == id then return p.label end
    end
    return id
end

local function permsText(list)
    if not list or #list == 0 then return 'No extra permissions' end
    local out = {}
    for _, id in ipairs(list) do out[#out + 1] = permLabel(id) end
    return table.concat(out, ', ')
end

local function has(d, perm)
    for _, p in ipairs(d.role.perms) do
        if p == perm then return true end
    end
    return false
end

-- Ranks the viewer is allowed to hand out.
local function lowerRanks(d)
    local out = {}
    for _, r in ipairs(d.ranks or {}) do
        if r.level < d.role.level then out[#out + 1] = r end
    end
    return out
end

local function rankOptions(d, skip)
    local out = {}
    for _, r in ipairs(lowerRanks(d)) do
        if r.id ~= skip then out[#out + 1] = { label = ('%s (level %d, %s)'):format(r.label, r.level, Rn.money(r.wage)), value = r.id } end
    end
    return out
end

local function confirm(header, content)
    return lib.alertDialog({ header = header, content = content, centered = true, cancel = true }) == 'confirm'
end

local function rankDialog(d, r)
    local permOptions = {}
    for _, id in ipairs(d.role.perms) do permOptions[#permOptions + 1] = { label = permLabel(id), value = id } end
    local top = d.role.level - 1
    local input = lib.inputDialog(r and ('Edit %s'):format(r.label) or 'New rank', {
        { type = 'input', label = 'Name', default = r and r.label or '', required = true, max = 24 },
        { type = 'number', label = ('Level (1 to %d). Higher ranks can manage lower ones'):format(top), default = r and r.level or math.min(top, 20), min = 1, max = top, required = true },
        { type = 'number', label = ('Wage each payday (up to %s)'):format(Rn.money(d.ownerWage)), default = r and r.wage or 0, min = 0, max = d.ownerWage, required = true },
        { type = 'multi-select', label = 'What this rank can do', options = permOptions, default = r and r.perms or {}, clearable = true },
    })
    if not input then return nil end
    return { label = input[1], level = input[2], wage = input[3], perms = input[4] or {} }
end

local function build(d)
    local id = d.id
    local reopen = function(sub) CreateThread(function() Rn.openOffice(id, sub) end) end

    local main = {
        {
            title = d.duty and 'Clock out' or 'Clock in',
            description = d.duty and ('You are on duty. Next payday in %d min'):format(math.ceil((d.payIn or 0) / 60)) or ('Wages are only paid while you are clocked in (every %d minutes)'):format(d.payMinutes),
            icon = d.duty and 'fa-solid fa-person-walking-arrow-right' or 'fa-solid fa-clock',
            onSelect = function()
                local ok = act(id, 'duty')
                reopen()
            end,
        },
        {
            title = ('%s at %s'):format(d.role.label, d.label),
            description = ('Wage: %s each payday, paid from the business account'):format(Rn.money(d.role.wage)),
            icon = 'fa-solid fa-id-badge', readOnly = true,
        },
    }

    if d.balance ~= nil then
        lib.registerContext({
            id = MAIN .. ':money', title = 'Business account', menu = MAIN,
            options = {
                { title = ('Balance: %s'):format(Rn.money(d.balance)), icon = 'fa-solid fa-vault', readOnly = true },
                {
                    title = 'Next payday', icon = 'fa-solid fa-calendar-check', readOnly = true,
                    description = (d.wagesDue or 0) == 0 and ('In %d min. Nobody is clocked in with a wage right now'):format(math.ceil((d.payIn or 0) / 60))
                        or (d.balance >= d.wagesDue and ('In %d min: %s in wages for staff on duty'):format(math.ceil((d.payIn or 0) / 60), Rn.money(d.wagesDue))
                        or ('In %d min: %s in wages due but only %s in the account, some staff will go unpaid'):format(math.ceil((d.payIn or 0) / 60), Rn.money(d.wagesDue), Rn.money(d.balance))),
                },
                {
                    title = 'Deposit money', icon = 'fa-solid fa-arrow-down',
                    onSelect = function()
                        local input = lib.inputDialog('Deposit money (cash or bank)', { { type = 'number', label = 'Amount', min = 1, required = true } })
                        if input and act(id, 'deposit', input[1]) then Rn.notify(('Deposited %s'):format(Rn.money(input[1])), 'success') end
                        reopen('money')
                    end,
                },
                {
                    title = 'Withdraw cash', icon = 'fa-solid fa-arrow-up',
                    onSelect = function()
                        local input = lib.inputDialog('Withdraw cash', { { type = 'number', label = 'Amount', min = 1, required = true } })
                        if input and act(id, 'withdraw', input[1]) then Rn.notify(('Withdrew %s'):format(Rn.money(input[1])), 'success') end
                        reopen('money')
                    end,
                },
            },
        })
        main[#main + 1] = { title = 'Business account', description = Rn.money(d.balance), icon = 'fa-solid fa-vault', menu = MAIN .. ':money', arrow = true }
    end

    if d.staff then
        local rows = {}
        for _, m in ipairs(d.staff) do
            local sub = ('%s:staff:%s'):format(MAIN, m.cid)
            local options = {
                { title = ('%s · %s'):format(m.name, m.rankLabel), description = ('%s%s'):format(Rn.money(m.wage), m.online and (m.duty and ' · on duty' or ' · online') or ' · offline'), icon = 'fa-solid fa-user', readOnly = true },
            }
            if m.manageable then
                options[#options + 1] = {
                    title = 'Change rank', icon = 'fa-solid fa-arrows-up-down',
                    onSelect = function()
                        local choices = rankOptions(d, m.rank)
                        if #choices == 0 then return Rn.notify('There is no other rank you can give', 'error') end
                        local input = lib.inputDialog(('Rank for %s'):format(m.name), { { type = 'select', label = 'New rank', options = choices, required = true } })
                        if input then act(id, 'setrank', m.cid, input[1]) end
                        reopen('staff')
                    end,
                }
                options[#options + 1] = {
                    title = 'Fire', icon = 'fa-solid fa-user-xmark',
                    onSelect = function()
                        if confirm('Fire ' .. m.name, 'They will lose their job here straight away.') then act(id, 'fire', m.cid) end
                        reopen('staff')
                    end,
                }
            end
            lib.registerContext({ id = sub, title = m.name, menu = MAIN .. ':staff', options = options })
            rows[#rows + 1] = { title = m.name, description = ('%s%s'):format(m.rankLabel, m.online and ' · online' or ' · offline'), icon = 'fa-solid fa-user', menu = sub, arrow = true }
        end
        table.insert(rows, 1, {
            title = 'Hire someone nearby', description = 'Offer a job to a player standing close to you', icon = 'fa-solid fa-user-plus',
            onSelect = function()
                local ok, res = act(id, 'nearby')
                if not ok then return reopen('staff') end
                if #res.players == 0 then
                    Rn.notify('Nobody without a restaurant job is close enough', 'error')
                    return reopen('staff')
                end
                local who = {}
                for _, p in ipairs(res.players) do who[#who + 1] = { label = ('%s (id %d)'):format(p.name, p.src), value = p.src } end
                local choices = rankOptions(d)
                if #choices == 0 then
                    Rn.notify('Create a rank first, one below yours', 'error')
                    return reopen('staff')
                end
                local input = lib.inputDialog('Hire', {
                    { type = 'select', label = 'Who', options = who, required = true },
                    { type = 'select', label = 'Rank', options = choices, required = true },
                })
                if input then
                    Rn.notify('Offer sent. Waiting for an answer', 'inform')
                    local sent, data = act(id, 'hire', input[1], input[2])
                    if sent then Rn.notify(('%s accepted and now works here'):format(data.name), 'success') end
                end
                reopen('staff')
            end,
        })
        lib.registerContext({ id = MAIN .. ':staff', title = ('Staff (%d)'):format(#d.staff), menu = MAIN, options = rows })
        main[#main + 1] = { title = 'Staff', description = ('%d on the team'):format(#d.staff), icon = 'fa-solid fa-people-group', menu = MAIN .. ':staff', arrow = true }
    end

    if d.ranks and has(d, 'ranks') then
        local rows = {
            {
                title = 'Create a rank', description = ('%d of %d used'):format(#d.ranks, d.limits.ranks), icon = 'fa-solid fa-plus',
                onSelect = function()
                    local data = rankDialog(d, nil)
                    if data then act(id, 'addrank', data) end
                    reopen('ranks')
                end,
            },
        }
        for _, r in ipairs(d.ranks) do
            local sub = ('%s:rank:%d'):format(MAIN, r.id)
            local options = {
                { title = ('%s · level %d'):format(r.label, r.level), description = ('%s · %s'):format(Rn.money(r.wage), permsText(r.perms)), icon = 'fa-solid fa-ranking-star', readOnly = true },
            }
            if r.editable then
                options[#options + 1] = {
                    title = 'Edit', icon = 'fa-solid fa-pen',
                    onSelect = function()
                        local data = rankDialog(d, r)
                        if data then act(id, 'editrank', r.id, data) end
                        reopen('ranks')
                    end,
                }
                options[#options + 1] = {
                    title = 'Delete', description = r.members > 0 and ('%d people are in this rank'):format(r.members) or nil, icon = 'fa-solid fa-trash',
                    onSelect = function()
                        if confirm('Delete ' .. r.label, 'This cannot be undone.') then act(id, 'delrank', r.id) end
                        reopen('ranks')
                    end,
                }
            end
            lib.registerContext({ id = sub, title = r.label, menu = MAIN .. ':ranks', options = options })
            rows[#rows + 1] = { title = r.label, description = ('Level %d · %s · %d people'):format(r.level, Rn.money(r.wage), r.members), icon = 'fa-solid fa-ranking-star', menu = sub, arrow = true }
        end
        lib.registerContext({ id = MAIN .. ':ranks', title = 'Ranks', menu = MAIN, options = rows })
        main[#main + 1] = { title = 'Ranks', description = 'Names, wages and what each rank can do', icon = 'fa-solid fa-ranking-star', menu = MAIN .. ':ranks', arrow = true }
    end

    if has(d, 'menu') then
        main[#main + 1] = {
            title = 'Menu and dishes', description = 'Prices, and design your own dishes', icon = 'fa-solid fa-book-open',
            onSelect = function() CreateThread(function() Rn.openMenu(id) end) end,
        }
    end

    if d.role.owner then
        main[#main + 1] = {
            title = 'My wage', description = ('%s each payday. The most you can set is %s'):format(Rn.money(d.ownerWage), Rn.money(d.maxWage)),
            icon = 'fa-solid fa-sack-dollar',
            onSelect = function()
                local input = lib.inputDialog('Your wage', {
                    { type = 'number', label = ('Wage each payday (up to %s). No rank can be paid more than you'):format(Rn.money(d.maxWage)), default = d.ownerWage, min = 0, max = d.maxWage, required = true },
                })
                if input and act(id, 'wage', input[1]) then Rn.notify('Wage updated', 'success') end
                reopen()
            end,
        }
    else
        main[#main + 1] = {
            title = 'Quit this job', icon = 'fa-solid fa-door-open',
            onSelect = function()
                if confirm('Quit ' .. d.label, 'You will have to be hired again to come back.') then
                    if act(id, 'quit') then return Rn.notify('You quit', 'inform') end
                end
                reopen()
            end,
        }
    end

    lib.registerContext({ id = MAIN, title = d.label, options = main, onExit = function() Rn.busy = false end })
end

function Rn.openOffice(id, sub)
    if Rn.busy then return end
    local ok, d, extra = Rn.call('office', id)
    if not ok then return Rn.fail(d, extra) end
    build(d)
    lib.showContext(sub and (MAIN .. ':' .. sub) or MAIN)
end
