local function cidOf(who)
    if type(who) == 'string' then return who end
    local n = tonumber(who)
    if not n then return nil end
    return Bridge.cid(n)
end

exports('HasBusinessLicence', function(who, typeId)
    local cid = cidOf(who)
    if not cid or not Db.ready then return false end
    return Biz.hasActive(cid, typeId)
end)

exports('GetBusinessLicences', function(who)
    local cid = cidOf(who)
    if not cid or not Db.ready then return {} end
    return Biz.list(cid)
end)

exports('GetLicenceByNumber', function(number)
    if not Db.ready then return nil end
    local row = Biz.byNumber(number)
    if not row then return nil end
    return Biz.present(row, os.time())
end)

exports('IssueBusinessLicence', function(src, typeId, name, days)
    local info = Core.info(src)
    if not info or not Db.ready then return false end
    local done, err, res = Biz.create(info, typeId, name, { free = true, force = true, days = days })
    return done, err, res
end)

exports('RevokeBusinessLicence', function(number, note)
    if not Db.ready then return false end
    return (Biz.revoke(number, note))
end)

exports('ReinstateBusinessLicence', function(number)
    if not Db.ready then return false end
    return (Biz.reinstate(number))
end)
