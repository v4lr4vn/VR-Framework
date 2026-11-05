DU = {}

function DU.money(n)
    n = math.floor(tonumber(n) or 0)
    local s = tostring(math.abs(n)):reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
    return (n < 0 and '-' or '') .. s
end

function DU.colorOk(id)
    id = tonumber(id)
    for _, c in ipairs(Config.Colors) do
        if c.id == id then return id end
    end
    return nil
end
