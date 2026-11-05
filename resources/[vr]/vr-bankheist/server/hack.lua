Hack = { sessions = {}, cool = {} }

local function fail(code) return { ok = false, error = code } end

local USERS = { 'mara', 'jonas', 'elin', 'sigrid', 'rolf', 'astrid', 'bjorn', 'freya' }

local LISTS = {
    names = { 'astrid', 'bjorn', 'freya', 'sigrid', 'rolf', 'elin', 'leif', 'ingrid' },
    pets = { 'bruno', 'pixel', 'mochi', 'biscuit', 'sable', 'juno', 'rex', 'pepper' },
    cities = { 'bergen', 'oslo', 'tromso', 'malmo', 'visby', 'aarhus', 'turku', 'lofoten' },
    teams = { 'rosenborg', 'brann', 'molde', 'valerenga', 'stabaek', 'haugesund', 'bodo', 'odd' },
    seasons = { 'winter', 'summer', 'autumn', 'spring', 'solstice', 'equinox', 'yule', 'midsummer' },
    colours = { 'crimson', 'indigo', 'amber', 'scarlet', 'violet', 'ochre', 'teal', 'ivory' },
    bands = { 'mayhem', 'enslaved', 'satyricon', 'emperor', 'darkthrone', 'immortal', 'gorgoroth', 'wardruna' },
}

local ORDER = { 'names', 'pets', 'cities', 'teams', 'seasons', 'colours', 'bands' }

local HINTS = {
    names = {
        'IT reminder: do not use family names for admin passwords. Yes, that includes {u}\'s sister.',
        '{u} changed the admin password again. Something personal, a person this time, plus the year.',
    },
    pets = {
        'IT reminder: pet names are not passwords. {u}, this means the office dog.',
        '{u} said the admin password is "someone who greets me at the door", plus the year.',
    },
    cities = {
        'IT reminder: holiday destinations are not passwords. {u}, I can see Bergen on your wall.',
        '{u}\'s new admin password is a place from the last trip, plus the year.',
    },
    teams = {
        'IT reminder: football clubs are not passwords. {u}, we all know who you support.',
        '{u} told me the admin password is "my club", plus the year. Again.',
    },
    seasons = {
        'IT reminder: seasons are not passwords. {u}, rotating them does not count.',
        '{u} swapped the admin password for the time of year, plus the year.',
    },
    colours = {
        'IT reminder: colours are not passwords. {u}, the paint swatches on your desk do not help.',
        '{u}\'s admin password matches the new office paint, plus the year.',
    },
    bands = {
        'IT reminder: bands are not passwords. {u}, the vinyl wall gives it away.',
        '{u} picked a band for the admin password, plus the year. Obviously.',
    },
}

local NOISE_MAIL = {
    { 'lunch.eml', 'From: facilities\nSubject: Lunch order\n\nThe canteen has fish again on Thursday. Vote now.' },
    { 'printer.eml', 'From: helpdesk\nSubject: Printer on 2\n\nThe printer on floor 2 is out of toner again. Please do not hit it.' },
    { 'rota.eml', 'From: ops\nSubject: Weekend rota\n\nNight cover this weekend: Rolf and Elin. Keys with the duty manager.' },
    { 'courier.eml', 'From: logistics\nSubject: Courier window\n\nThe armoured courier moves to 14:30 on Tuesdays. Please update the board.' },
    { 'audit.eml', 'From: compliance\nSubject: Audit prep\n\nExternal audit starts on the 12th. Tidy your shares.' },
    { 'parking.eml', 'From: facilities\nSubject: Parking\n\nStaff parking is closed on Friday for resurfacing.' },
}

local EXPLOITS = {
    vault = {
        service = 'vaultd', pretty = 'vault controller', cmd = 'vaultctl', verb = 'unlock',
        pool = { 'vaultd-2.0-overflow', 'vaultd-2.1-heap', 'vaultd-2.2-authbypass', 'vaultd-1.9-format', 'camd-2.1-overflow', 'doorsrv-2.1-heap', 'httpd-2.1-traversal' },
    },
    alarm = {
        service = 'alarmd', pretty = 'alarm controller', cmd = 'alarmctl', verb = 'disable',
        pool = { 'alarmd-3.0-overflow', 'alarmd-3.1-heap', 'alarmd-3.2-authbypass', 'alarmd-2.9-format', 'camd-3.1-overflow', 'doorsrv-3.1-heap', 'httpd-3.1-traversal' },
    },
}

local function pick(list) return list[math.random(#list)] end

local function shuffle(list)
    local out = {}
    for i = 1, #list do out[i] = list[i] end
    for i = #out, 2, -1 do
        local j = math.random(i)
        out[i], out[j] = out[j], out[i]
    end
    return out
end

local function hex(n)
    local t = {}
    for i = 1, n do t[i] = ('%x'):format(math.random(0, 15)) end
    return table.concat(t)
end

local function dir(children) return { dir = true, children = children or {} } end
local function file(text, flag) return { text = text, flag = flag } end

local function build(el, tier)
    local goal = EXPLOITS[el.goal] or EXPLOITS.vault
    local user = pick(USERS)
    local cat = pick(ORDER)
    local word = pick(LISTS[cat])
    local year = tostring(math.random(1974, 2004))
    local password = word .. year
    local count = math.min(Config.Hack.wordlists[tier], #ORDER)
    local cats = { cat }
    for _, c in ipairs(shuffle(ORDER)) do
        if #cats < count and c ~= cat then cats[#cats + 1] = c end
    end
    cats = shuffle(cats)
    local lists = {}
    for _, c in ipairs(cats) do
        local words = shuffle(LISTS[c])
        local picked = {}
        for _, w in ipairs(words) do
            if c == cat or w ~= word then picked[#picked + 1] = w end
            if #picked >= 6 then break end
        end
        if c == cat then
            local has = false
            for _, w in ipairs(picked) do if w == word then has = true end end
            if not has then picked[1] = word end
        end
        lists[c .. '.lst'] = file(table.concat(picked, '\n'))
    end
    local hintText = HINTS[cat][tier <= 2 and 1 or 2]:gsub('{u}', user:sub(1, 1):upper() .. user:sub(2))
    local mails = {}
    local pool = shuffle(NOISE_MAIL)
    local noise = math.random(2, 3)
    for i = 1, noise do mails[pool[i][1]] = file(pool[i][2]) end
    mails['it-notice.eml'] = file(('From: it-security\nSubject: Password reminder\n\n%s\n\nFormat: <word><year>'):format(hintText))
    local token = hex(8)
    local home = dir({
        ['README.txt'] = file(('%s staff gateway\nUnauthorised access is logged.\nType help for the commands on this terminal.'):format(el.host)),
        inbox = dir(mails),
        notes = dir({ ['todo.txt'] = file('- renew certificates\n- move vault controller to the new subnet\n- ask facilities about the door sensor') }),
        wordlists = dir(lists),
        ['.cache'] = dir({ ['session.tok'] = file(('token=%s\nissued by %s'):format(token, el.host)) }),
    })
    local decoys = Config.Hack.decoys[tier]
    if decoys >= 1 then
        home.children['payroll.csv'] = file('name,iban,salary\n[redacted]', 'canary')
    end
    if decoys >= 2 then
        home.children.notes.children['passwords.txt'] = file('admin : ********\nbackup : ********', 'canary')
    end
    if decoys >= 3 then
        home.children.inbox.children['urgent-reset.eml'] = file('From: it-security\nSubject: URGENT reset\n\nClick the link to reset: http://reset.example', 'canary')
    end
    local version = ('%d.%d'):format(math.random(1, 3), math.random(0, 3))
    local patch = math.random(1, 9)
    local good = ('%s-%s-%s'):format(goal.service, version, pick({ 'heap', 'overflow', 'authbypass', 'format' }))
    local list = shuffle(goal.pool)
    local exploits = { good }
    for _, name in ipairs(list) do
        if #exploits < 5 and name ~= good and name:gsub('%-%a+$', '') ~= good:gsub('%-%a+$', '') then exploits[#exploits + 1] = name end
    end
    exploits = shuffle(exploits)
    return {
        user = user,
        cat = cat,
        password = password,
        token = token,
        fs = dir({ home = dir({ [user] = home }) }),
        cwd = { 'home', user },
        goal = goal,
        version = version .. '.' .. patch,
        major = version,
        good = good,
        exploits = exploits,
        lists = lists,
    }
end

local function resolve(world, path)
    local parts = {}
    if path:sub(1, 1) == '/' then
        for seg in path:gmatch('[^/]+') do parts[#parts + 1] = seg end
    elseif path == '~' or path:sub(1, 2) == '~/' then
        parts = { 'home', world.user }
        for seg in path:sub(3):gmatch('[^/]+') do parts[#parts + 1] = seg end
    else
        for _, seg in ipairs(world.cwd) do parts[#parts + 1] = seg end
        for seg in path:gmatch('[^/]+') do parts[#parts + 1] = seg end
    end
    local out = {}
    for _, seg in ipairs(parts) do
        if seg == '..' then
            if #out > 0 then out[#out] = nil end
        elseif seg ~= '.' then
            out[#out + 1] = seg
        end
    end
    local node = world.fs
    for _, seg in ipairs(out) do
        if not node.dir or not node.children[seg] then return nil, out end
        node = node.children[seg]
    end
    return node, out
end

local function promptOf(s)
    local w = s.world
    local shown = '/' .. table.concat(w.cwd, '/')
    local home = '/home/' .. w.user
    if shown == home then
        shown = '~'
    elseif shown:sub(1, #home + 1) == home .. '/' then
        shown = '~' .. shown:sub(#home + 1)
    end
    local mark = s.access == 'root' and '#' or '$'
    return ('%s@%s:%s%s'):format(s.access == 'none' and 'guest' or w.user, s.hostname, shown, mark)
end

local function out(lines, kind, text, delay)
    lines[#lines + 1] = { k = kind, t = text, d = delay }
end

local TOOL_HELP = {
    heimdall = 'heimdall <host> [--deep]    scan a host for open services. --deep reads the exact version',
    fenrir = 'fenrir <host> <wordlist>      try every entry of a wordlist against the login',
    gungnir = 'gungnir list | use <exploit>  list the exploit modules or stage one',
    mjolnir = 'mjolnir <host> [--token <t>]  escalate privileges on a host you can log in to',
    hel = 'hel wipe                       wipe the logs. Works once and needs root',
}

local function help(s, lines)
    out(lines, 'dim', 'Odin\'s Eye shell. Tools:')
    for _, name in ipairs({ 'heimdall', 'fenrir', 'gungnir', 'mjolnir', 'hel' }) do
        out(lines, 'out', '  ' .. TOOL_HELP[name])
    end
    out(lines, 'dim', 'Shell: ls [-a] [dir]  cd <dir>  pwd  cat <file>  whoami  clear  exit')
    out(lines, 'dim', ('Host utility: sudo %s %s (root only)'):format(s.world.goal.cmd, s.world.goal.verb))
end

local function addTrace(s, n)
    s.trace = math.max(0, math.min(100, s.trace + n))
end

local function hostMatches(s, arg)
    if not arg then return false end
    arg = arg:lower()
    return arg == s.hostname or arg == s.ip or arg == s.host:lower()
end

local function listName(arg)
    if not arg then return nil end
    local base = arg:match('([^/]+)$') or arg
    base = base:gsub('%.lst$', '')
    return base .. '.lst'
end

local COMMANDS = {}

COMMANDS.help = function(s, a, lines) help(s, lines) end
COMMANDS.man = function(s, a, lines)
    local t = a[2]
    if t and TOOL_HELP[t] then out(lines, 'out', TOOL_HELP[t]) else out(lines, 'err', 'man: no manual entry for ' .. tostring(t or '')) end
end
COMMANDS.whoami = function(s, a, lines)
    out(lines, 'out', s.access == 'none' and 'guest' or (s.access == 'root' and 'root' or s.world.user))
end
COMMANDS.pwd = function(s, a, lines)
    out(lines, 'out', '/' .. table.concat(s.world.cwd, '/'))
end
COMMANDS.clear = function(s, a, lines, res) res.clear = true end
COMMANDS.exit = function(s, a, lines, res)
    out(lines, 'dim', 'connection closed')
    res.closed = true
end
COMMANDS.logout = COMMANDS.exit

COMMANDS.ls = function(s, a, lines)
    local all, path = false, nil
    for i = 2, #a do
        if a[i] == '-a' or a[i] == '-la' or a[i] == '-al' then all = true else path = a[i] end
    end
    local node = resolve(s.world, path or '.')
    if not node then return out(lines, 'err', ('ls: cannot access \'%s\': no such file or directory'):format(path or '')) end
    if not node.dir then return out(lines, 'out', path) end
    local names = {}
    for name in pairs(node.children) do
        if all or name:sub(1, 1) ~= '.' then names[#names + 1] = name end
    end
    table.sort(names)
    if #names == 0 then return out(lines, 'dim', '(empty)') end
    local row = {}
    for _, name in ipairs(names) do
        row[#row + 1] = node.children[name].dir and (name .. '/') or name
    end
    out(lines, 'out', table.concat(row, '   '))
end

COMMANDS.cd = function(s, a, lines)
    local node, parts = resolve(s.world, a[2] or '~')
    if not node then return out(lines, 'err', ('cd: %s: no such file or directory'):format(a[2] or '')) end
    if not node.dir then return out(lines, 'err', ('cd: %s: not a directory'):format(a[2])) end
    s.world.cwd = parts
end

COMMANDS.cat = function(s, a, lines)
    if not a[2] then return out(lines, 'err', 'cat: missing file') end
    local node = resolve(s.world, a[2])
    if not node then return out(lines, 'err', ('cat: %s: no such file or directory'):format(a[2])) end
    if node.dir then return out(lines, 'err', ('cat: %s: is a directory'):format(a[2])) end
    for line in (node.text .. '\n'):gmatch('(.-)\n') do out(lines, 'out', line) end
    if node.flag == 'canary' and not node.tripped then
        node.tripped = true
        addTrace(s, 15)
        out(lines, 'warn', '[!] canary file opened. This access has been logged')
    end
end

COMMANDS.heimdall = function(s, a, lines)
    if not hostMatches(s, a[2]) then
        return out(lines, 'err', a[2] and ('heimdall: could not resolve host ' .. a[2]) or 'usage: heimdall <host> [--deep]')
    end
    local deep = a[3] == '--deep'
    local needDeep = Config.Hack.needDeepScan[s.tier]
    addTrace(s, deep and 8 or 5)
    out(lines, 'dim', ('Heimdall 1.4 scanning %s (%s)'):format(s.hostname, s.ip), 250)
    out(lines, 'out', 'PORT      STATE   SERVICE', 300)
    out(lines, 'out', '22/tcp    open    ssh (login gateway)', 120)
    out(lines, 'out', '80/tcp    open    httpd (status page)', 120)
    local g = s.world.goal
    if needDeep and not deep then
        out(lines, 'out', ('4410/tcp  open    %s (version hidden)'):format(g.service), 120)
        out(lines, 'warn', 'Version fingerprint blocked. Re-run with --deep', 200)
    else
        out(lines, 'out', ('4410/tcp  open    %s %s'):format(g.service, s.world.version), 120)
        s.deep = true
    end
    s.scanned = true
    out(lines, 'ok', 'Scan complete', 150)
end

COMMANDS.fenrir = function(s, a, lines)
    if not a[2] or not a[3] then return out(lines, 'err', 'usage: fenrir <host> <wordlist>') end
    if not hostMatches(s, a[2]) then return out(lines, 'err', 'fenrir: could not resolve host ' .. a[2]) end
    if not s.scanned then return out(lines, 'err', 'fenrir: no service fingerprint for this host. Run heimdall first') end
    if s.access ~= 'none' then return out(lines, 'dim', 'fenrir: already authenticated') end
    local name = listName(a[3])
    local list = s.world.lists[name]
    if not list then return out(lines, 'err', ('fenrir: wordlist %s not found'):format(a[3])) end
    out(lines, 'dim', ('Fenrir 2.0 trying %s against ssh://%s:22'):format(name, s.hostname), 300)
    out(lines, 'out', 'candidate x year (1974-2004)', 700)
    if name == s.world.cat .. '.lst' then
        addTrace(s, 6)
        s.access = 'user'
        out(lines, 'ok', ('[+] valid login: %s : %s'):format(s.world.user, s.world.password), 900)
        out(lines, 'ok', ('logged in as %s'):format(s.world.user), 150)
    else
        addTrace(s, 14)
        out(lines, 'err', ('[-] wordlist exhausted, no match (%d attempts logged)'):format(math.random(2000, 9000)), 900)
        out(lines, 'warn', 'The target logged repeated failed logins', 150)
    end
end

COMMANDS.gungnir = function(s, a, lines)
    if not s.scanned then return out(lines, 'err', 'gungnir: nothing to target. Run heimdall first') end
    if a[2] == 'list' then
        out(lines, 'dim', 'Available modules:')
        for _, name in ipairs(s.world.exploits) do out(lines, 'out', '  ' .. name) end
        return
    elseif a[2] == 'use' and a[3] then
        local known = false
        for _, name in ipairs(s.world.exploits) do if name == a[3] then known = true end end
        if not known then return out(lines, 'err', ('gungnir: unknown module %s'):format(a[3])) end
        if not s.deep and Config.Hack.needDeepScan[s.tier] then
            addTrace(s, 10)
            return out(lines, 'err', 'gungnir: target version unknown. The module was fired blind and failed')
        end
        if a[3] == s.world.good then
            s.loaded = true
            addTrace(s, 4)
            out(lines, 'ok', ('module %s staged against %s'):format(a[3], s.hostname), 400)
        else
            s.loaded = false
            addTrace(s, 12)
            out(lines, 'err', ('exploit failed: target is not vulnerable to %s'):format(a[3]), 500)
            out(lines, 'dim', ('the target runs %s %s'):format(s.world.goal.service, s.deep and s.world.version or 'unknown'))
        end
        return
    end
    out(lines, 'err', 'usage: gungnir list | gungnir use <exploit>')
end

COMMANDS.mjolnir = function(s, a, lines)
    if not hostMatches(s, a[2]) then return out(lines, 'err', a[2] and ('mjolnir: could not resolve host ' .. a[2]) or 'usage: mjolnir <host> [--token <t>]') end
    if s.access == 'none' then return out(lines, 'err', 'mjolnir: no session on the target. Log in first') end
    if s.access == 'root' then return out(lines, 'dim', 'mjolnir: already root') end
    if not s.loaded then return out(lines, 'err', 'mjolnir: no exploit staged. Use gungnir first') end
    local token
    if a[3] == '--token' then token = a[4] end
    addTrace(s, 8)
    out(lines, 'dim', 'Mjolnir 3.1 forging privilege token', 400)
    if Config.Hack.needToken[s.tier] and token ~= s.world.token then
        addTrace(s, 10)
        return out(lines, 'err', token and 'mjolnir: token rejected' or 'mjolnir: this host requires a session token (--token). Look for a cached one', 500)
    end
    s.access = 'root'
    out(lines, 'ok', 'privilege escalation complete: uid=0(root)', 700)
end

COMMANDS.hel = function(s, a, lines)
    if a[2] ~= 'wipe' then return out(lines, 'err', 'usage: hel wipe') end
    if s.access ~= 'root' then return out(lines, 'err', 'hel: permission denied') end
    if s.wiped then return out(lines, 'dim', 'hel: logs already wiped') end
    s.wiped = true
    out(lines, 'dim', 'Hel is scrubbing auth.log, access.log and the audit trail', 600)
    if s.done then
        s.wipeBonus = true
        out(lines, 'ok', 'trail erased. The police response will be slower', 400)
    else
        addTrace(s, -25)
        out(lines, 'ok', 'trail erased. Trace reduced', 400)
    end
end

COMMANDS.sudo = function(s, a, lines)
    local g = s.world.goal
    if a[2] ~= g.cmd then return out(lines, 'err', ('sudo: %s: command not found'):format(tostring(a[2] or ''))) end
    if a[3] ~= g.verb then return out(lines, 'err', ('usage: sudo %s %s'):format(g.cmd, g.verb)) end
    if s.access ~= 'root' then
        addTrace(s, 6)
        return out(lines, 'err', ('sudo: %s is not in the sudoers file. This incident will be reported'):format(s.access == 'none' and 'guest' or s.world.user))
    end
    if s.done then return out(lines, 'dim', g.cmd .. ': already done') end
    out(lines, 'dim', ('%s: contacting the %s'):format(g.cmd, g.pretty), 500)
    s.finish = true
    out(lines, 'ok', ('%s: %s %s'):format(g.cmd, g.verb, g.cmd == 'vaultctl' and 'command accepted. Locks are releasing' or 'command accepted. Sirens are muted'), 800)
end

local function split(raw)
    local parts = {}
    for token in raw:gmatch('%S+') do
        if #parts >= 8 or #token > 64 then return nil end
        parts[#parts + 1] = token
    end
    return parts
end

local function fold(s, res)
    local now = GetGameTimer()
    local elapsed = (now - s.at) / 1000
    s.at = now
    s.trace = math.min(100, s.trace + elapsed * Config.Hack.traceRate[s.tier])
    res.trace = math.floor(s.trace + 0.5)
end

local function fall(src, s, reason)
    local bank = Banks.get(s.bank)
    Hack.sessions[src] = nil
    Hack.cool[src] = os.time() + Config.Hack.failCooldownSeconds
    if bank then
        local run = Heist.begin(bank, src)
        Heist.alert(bank, run, src, reason)
        Heist.push(bank)
    end
end

local function success(src, s)
    local bank = Banks.get(s.bank)
    local el = bank and BH.byId(bank, s.el)
    if not bank or not el then return false end
    local run = Heist.begin(bank, src)
    s.done = true
    Heist.complete(bank, run, el, src)
    return true
end

lib.callback.register('vr-bankheist:hack:open', function(src, bankId, elId)
    if Core.throttle(src, 'hackopen', 1000) then return fail('slow_down') end
    if Hack.sessions[src] then return fail('busy') end
    if (Hack.cool[src] or 0) > os.time() then return fail('hack_cooldown') end
    local bank, el, run = Heist.access(src, bankId, elId, { hack = true })
    if not bank then return fail(el) end
    if run and run.el[el.id].done then return fail('empty') end
    if Config.Hack.provider ~= 'builtin' then
        TriggerEvent('vr-bankheist:hackRequested', src, bank.name, el.id, { host = el.host, tier = el.tier, goal = el.goal })
        return { ok = true, data = { external = true } }
    end
    if Core.count(src, Config.Items.laptop) < 1 then return fail('need_laptop') end
    local tier = math.max(1, math.min(5, math.floor(el.tier)))
    if tier >= Config.Hack.consumeKitFromTier then
        if Core.count(src, Config.Items.kit) < 1 then return fail('need_kit') end
        Core.take(src, Config.Items.kit, 1)
    end
    local hostname = el.host:lower():gsub('[^%w%-]', '-') .. '.lan'
    local s = {
        bank = bank.id, el = el.id, tier = tier, host = el.host, hostname = hostname,
        ip = ('10.%d.%d.%d'):format(math.random(2, 60), math.random(1, 250), math.random(2, 250)),
        trace = 0, access = 'none', at = GetGameTimer(), opened = GetGameTimer(),
        expires = GetGameTimer() + Config.Hack.seconds[tier] * 1000,
        world = nil, last = 0,
    }
    s.world = build(el, tier)
    Hack.sessions[src] = s
    return {
        ok = true,
        data = {
            host = el.host, hostname = hostname, ip = s.ip, tier = tier,
            seconds = Config.Hack.seconds[tier], rate = Config.Hack.traceRate[tier],
            ward = ({ 'Bronze Ward', 'Iron Ward', 'Steel Ward', 'Rune Ward', 'Aegis' })[tier],
            prompt = promptOf(s),
            user = s.world.user,
        },
    }
end)

lib.callback.register('vr-bankheist:hack:cmd', function(src, raw)
    local s = Hack.sessions[src]
    if not s then return fail('no_session') end
    if type(raw) ~= 'string' or #raw > 200 then return fail('bad_request') end
    if Core.throttle(src, 'hackcmd', 180) then return fail('slow_down') end
    local lines, res = {}, {}
    local bank = Banks.get(s.bank)
    local el = bank and BH.byId(bank, s.el)
    if not el or not Core.near(src, el, (el.r or 2.0) + 12.0) then
        Hack.sessions[src] = nil
        return { ok = true, data = { lines = { { k = 'err', t = 'connection lost: out of range' } }, closed = true } }
    end
    fold(s, res)
    if GetGameTimer() > s.expires and not s.done then
        fall(src, s, 'the intruder was traced')
        return { ok = true, data = { lines = { { k = 'err', t = 'session timed out. The host dropped your connection' } }, closed = true, failed = true, trace = 100 } }
    end
    local a = split(raw)
    if a == nil then
        out(lines, 'err', 'input rejected')
    elseif #a > 0 then
        local fn = COMMANDS[a[1]]
        if fn then
            fn(s, a, lines, res)
        else
            out(lines, 'err', ('%s: command not found'):format(a[1]))
        end
    end
    res.trace = math.floor(math.min(100, s.trace) + 0.5)
    if s.trace >= Config.Hack.failTraceCut and not s.done then
        out(lines, 'err', '[!] TRACE COMPLETE. Connection terminated by the host')
        fall(src, s, 'the intruder was traced')
        res.closed, res.failed = true, true
        res.trace = 100
    elseif s.finish and not s.done then
        if success(src, s) then
            res.done = true
            out(lines, 'dim', 'Use hel wipe to cover your tracks, then exit')
        else
            out(lines, 'err', 'the host rejected the command')
        end
        s.finish = nil
    end
    if res.closed and not res.failed then
        if s.done and s.wipeBonus then
            local b = Banks.get(s.bank)
            local run = b and Heist.run[b.id]
            if run then run.extra = (run.extra or 0) + Config.Hack.wipeDelayBonus end
        end
        Hack.sessions[src] = nil
    end
    res.lines = lines
    res.prompt = Hack.sessions[src] and promptOf(s) or nil
    return { ok = true, data = res }
end)

lib.callback.register('vr-bankheist:hack:close', function(src)
    local s = Hack.sessions[src]
    if s and s.done and s.wipeBonus then
        local b = Banks.get(s.bank)
        local run = b and Heist.run[b.id]
        if run then run.extra = (run.extra or 0) + Config.Hack.wipeDelayBonus end
    end
    Hack.sessions[src] = nil
    return { ok = true }
end)

AddEventHandler('playerDropped', function()
    Hack.sessions[source] = nil
    Hack.cool[source] = nil
end)

exports('CompleteHack', function(src, bankName, elId)
    local bank = Banks.find(bankName)
    if not bank then return false end
    local el = BH.byId(bank, math.floor(tonumber(elId) or -1))
    if not el or el.type ~= 'hack' then return false end
    local run = Heist.begin(bank, src)
    Heist.complete(bank, run, el, src)
    return true
end)

exports('FailHack', function(src, bankName)
    local bank = Banks.find(bankName)
    if not bank then return false end
    local run = Heist.begin(bank, src)
    Heist.alert(bank, run, src, 'the intruder was traced')
    Heist.push(bank)
    return true
end)
