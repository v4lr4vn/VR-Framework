local function reply(src, text, kind)
    if src > 0 then Core.notify(src, text, kind or 'inform', 'Bank admin') else print(('[vr-banking] %s'):format(text)) end
end

local function targetCid(src, arg)
    if arg == nil or arg == 'me' then return src > 0 and Core.cid(src) or nil end
    local id = tonumber(arg)
    if id then return Core.cid(id) end
    if type(arg) == 'string' and arg ~= '' then return arg:upper() end
end

local function pickLoan(src, args)
    local cid = targetCid(src, args.target)
    if not cid then
        reply(src, 'Player not found. Use their server id, me or a citizen id.', 'error')
        return nil
    end
    local loan
    if args.loan then
        loan = Loans.get(args.loan)
        if not loan or loan.cid ~= cid then
            reply(src, ('Loan #%s does not belong to %s'):format(tostring(args.loan), cid), 'error')
            return nil
        end
    else
        loan = Loans.latestFor(cid)
        if not loan then
            reply(src, ('%s has no active loan. Open one at a bank branch or finance a car first.'):format(cid), 'error')
            return nil
        end
    end
    return loan
end

local function describe(r)
    if r.status == 'collections' then
        local text = ('Loan #%d defaulted. Case #%s opened for $%s.'):format(r.id, tostring(r.caseId or '?'), Fmt.money(r.remaining))
        if r.plate then text = text .. (' Tracker on for %s.'):format(r.plate) end
        return text, 'error'
    end
    return ('Loan #%d: %d of %d missed, $%s late fee, $%s overdue.'):format(r.id, r.missed, r.defaultAfter, Fmt.money(r.fee or 0), Fmt.money(r.arrears)), 'inform'
end

local TARGET = { name = 'target', type = 'string', help = 'Server id, me or citizen id', optional = true }
local LOAN = { name = 'loan', type = 'number', help = 'Loan id (latest active loan if left out)', optional = true }

lib.addCommand('loanmiss', { help = 'Test: make a loan miss its next payment now', params = { TARGET, LOAN }, restricted = true }, function(src, args)
    local loan = pickLoan(src, args)
    if not loan then return end
    local ok, r = Loans.forceMiss(loan.id)
    if not ok then return reply(src, ('Could not miss a payment on loan #%d (%s)'):format(loan.id, tostring(r)), 'error') end
    reply(src, describe(r))
end)

lib.addCommand('loandefault', { help = 'Test: default a loan now and send it to collections', params = { TARGET, LOAN }, restricted = true }, function(src, args)
    local loan = pickLoan(src, args)
    if not loan then return end
    local ok, r = Loans.forceMiss(loan.id, true)
    if not ok then return reply(src, ('Could not default loan #%d (%s)'):format(loan.id, tostring(r)), 'error') end
    reply(src, describe(r))
end)

lib.addCommand('loandue', { help = 'Test: take the next loan payment now, from their bank balance', params = { TARGET, LOAN }, restricted = true }, function(src, args)
    local loan = pickLoan(src, args)
    if not loan then return end
    local ok, r = Loans.dueNow(loan.id)
    if not ok then return reply(src, ('Could not charge loan #%d (%s)'):format(loan.id, tostring(r)), 'error') end
    if r.paid then return reply(src, ('Loan #%d payment taken. $%s left.'):format(loan.id, Fmt.money(r.loan.remaining)), 'success') end
    reply(src, describe(r.loan))
end)

lib.addCommand('loans', { help = 'List a player\'s loans', params = { TARGET }, restricted = true }, function(src, args)
    local cid = targetCid(src, args.target)
    if not cid then return reply(src, 'Player not found', 'error') end
    local list = Loans.forPlayer(cid)
    if #list == 0 then return reply(src, ('%s has no loans'):format(cid)) end
    for _, l in ipairs(list) do
        reply(src, ('#%d %s · %s · $%s left · missed %d%s'):format(l.id, l.kind, l.status, Fmt.money(l.remaining), l.missed, l.plate and (' · car ' .. l.plate) or ''))
    end
end)

lib.addCommand('repostage', { help = 'Park collateral cars of open cases on the street now', params = { { name = 'plate', type = 'string', help = 'Plate (all open cases if left out)', optional = true } }, restricted = true }, function(src, args)
    if args.plate then
        local plate = Loans.plateKey(args.plate)
        local c = Collections.collateral()[plate]
        if not c then return reply(src, ('%s is not collateral on an open case'):format(tostring(plate)), 'error') end
        local ok, how = Repo.stage(c, plate, c.model, false)
        return reply(src, ok and ('%s: %s'):format(plate, how == 'out' and 'already out, tracker on' or 'parked on the street, tracker on') or ('%s: %s'):format(plate, tostring(how)), ok and 'success' or 'error')
    end
    Repo.ensure()
    local n = 0
    for _ in pairs(Collections.collateral()) do n = n + 1 end
    reply(src, ('Checked %d collateral vehicle(s) on open cases'):format(n), 'success')
end)

lib.addCommand('repospot', { help = 'Add a street spot for repo cars where you stand (or remove the nearest)', params = { { name = 'action', type = 'string', help = 'add or remove', optional = true } }, restricted = true }, function(src, args)
    if src <= 0 then return end
    local ped = GetPlayerPed(src)
    local veh = GetVehiclePedIsIn(ped, false)
    local ent = veh ~= 0 and veh or ped
    local pos = GetEntityCoords(ent)
    if args.action == 'remove' then
        return reply(src, Repo.removeSpotNear(pos, 6.0) and 'Spot removed' or 'No added spot within 6m. Spots in config.lua are edited there.', 'inform')
    end
    local id = Repo.addSpot(pos, GetEntityHeading(ent), Core.cid(src))
    reply(src, id and ('Repo spot #%d saved. Park facing the way the car should sit.'):format(id) or 'Could not save the spot', id and 'success' or 'error')
end)

lib.addCommand('repospots', { help = 'Show every repo street spot on your map for two minutes', restricted = true }, function(src)
    if src <= 0 then return end
    local list = {}
    for _, s in ipairs(Repo.spots()) do list[#list + 1] = { x = s.x, y = s.y, z = s.z, config = s.config == true } end
    TriggerClientEvent('vr-banking:client:showSpots', src, list)
    reply(src, ('%d repo spots shown on your map'):format(#list))
end)

lib.addCommand('repocheck', { help = 'Show where every repo car on an open case is', restricted = true }, function(src)
    local list = Collections.withCollateral()
    if #list == 0 then return reply(src, 'No open cases with a car on them') end
    for _, e in ipairs(list) do
        local text
        if e.held then
            text = 'repossessed, held by the bank'
        else
            local s = Repo.status(e.plate)
            if s.onStreet then
                text = ('on the street at %.0f, %.0f, tracker on'):format(s.x, s.y)
            elseif s.garageState == 2 then
                text = 'in the police impound'
            else
                text = ('not on the street%s'):format(s.last and (' (' .. tostring(s.last) .. ')') or ', checking again soon')
            end
        end
        reply(src, ('Case #%d · %s · %s'):format(e.case.id, e.plate, text))
    end
end)
