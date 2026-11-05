MU = {}

function MU.money(n)
    n = math.floor(tonumber(n) or 0)
    local s = tostring(math.abs(n)):reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
    return (n < 0 and '-' or '') .. s
end

function MU.plate(p)
    if type(p) ~= 'string' then return nil end
    p = p:upper():gsub('^%s+', ''):gsub('%s+$', '')
    return p ~= '' and p or nil
end

function MU.fullStatus(s)
    local out = {}
    for part in pairs(Config.Parts) do
        local v = type(s) == 'table' and tonumber(s[part]) or nil
        out[part] = v and math.max(0, math.min(100, v)) or 100.0
    end
    return out
end

function MU.isMechanic(job)
    return type(job) == 'table' and Config.Jobs[job.name] == true and job.onduty == true
end
