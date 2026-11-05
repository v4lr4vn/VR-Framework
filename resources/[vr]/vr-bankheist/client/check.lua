local function why(bank, el, zone, here, aim)
    local reasons = {}
    local pos = vec3(el.x, el.y, el.z)
    if not zone then
        reasons[#reasons + 1] = 'no target zone exists for this step'
        return reasons
    end
    if not bank.enabled then reasons[#reasons + 1] = 'bank is switched off' end
    local st = BHC.status[bank.id]
    if st and st.state ~= 'idle' and st.state ~= 'active' then reasons[#reasons + 1] = ('bank is on %s'):format(st.state) end
    if el.needs then
        local need = st and st.el and (st.el[tostring(el.needs)] or st.el[el.needs])
        if not need or need.d ~= true then reasons[#reasons + 1] = ('waiting for step #%d first'):format(el.needs) end
    end
    if BHC.busy then reasons[#reasons + 1] = 'you are busy with another action' end
    if not aim then
        reasons[#reasons + 1] = 'you are not aiming at anything'
    else
        if #(aim - pos) > zone.radius then reasons[#reasons + 1] = ('your aim is %.1fm from the spot, aim within %.1fm'):format(#(aim - pos), zone.radius) end
        if #(here - aim) > zone.reach then reasons[#reasons + 1] = ('you are %.1fm from what you aim at, get within %.1fm'):format(#(here - aim), zone.reach) end
    end
    return reasons
end

RegisterCommand('heistzones', function()
    if not lib.callback.await('vr-bankheist:isAdmin', false) then return end
    local here = GetEntityCoords(BHC.ped())
    local hit, _, aim = lib.raycast.fromCamera(511, 4, 20.0)
    if not hit then aim = nil end
    local rows = {}
    for _, bank in ipairs(BHC.banks) do
        for _, el in ipairs(bank.elements or {}) do
            if el.type == 'hack' or el.type == 'drill' or el.type == 'cash' or el.type == 'gold' or el.type == 'till' or el.type == 'case' then
                local d = #(here - vec3(el.x, el.y, el.z))
                if d < 80.0 then rows[#rows + 1] = { bank = bank, el = el, d = d } end
            end
        end
    end
    table.sort(rows, function(a, b) return a.d < b.d end)
    print(('^3[vr-bankheist] %d banks, %d target zones, you are at %.1f %.1f %.1f^0'):format(#BHC.banks, #BHC.zones, here.x, here.y, here.z))
    if #rows == 0 then
        BHC.notify(('No hack, drill, register, case or loot step within 80m. Banks loaded: %d'):format(#BHC.banks), 'error')
        return
    end
    for i = 1, math.min(4, #rows) do
        local row = rows[i]
        local zone = BHC.zoneOf[('%d:%d'):format(row.bank.id, row.el.id)]
        local exists = zone and Bridge.target.zoneExists(zone.id) or false
        local reasons = why(row.bank, row.el, exists and zone or nil, here, aim)
        local line = ('%s #%d %s, %.1fm away: %s'):format(row.bank.label, row.el.id, row.el.type, row.d, #reasons == 0 and 'should show on the target' or table.concat(reasons, '; '))
        print('^3[vr-bankheist] ' .. line .. '^0')
        if i == 1 then BHC.notify(line, #reasons == 0 and 'success' or 'inform') end
    end
end, false)
