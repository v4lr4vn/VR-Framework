Database.PlayerSkins = {}

function Database.PlayerSkins.UpdateActiveField(citizenID, active)
    MySQL.update.await("UPDATE vr_clothing_skins SET active = ? WHERE citizenid = ?", {active, citizenID})
end

function Database.PlayerSkins.DeleteByModel(citizenID, model)
    MySQL.query.await("DELETE FROM vr_clothing_skins WHERE citizenid = ? AND model = ?", {citizenID, model})
end

function Database.PlayerSkins.Add(citizenID, model, appearance, active)
    MySQL.insert.await("INSERT INTO vr_clothing_skins (citizenid, model, skin, active) VALUES (?, ?, ?, ?)", {citizenID, model, appearance, active})
end

function Database.PlayerSkins.GetByCitizenID(citizenID, model)
    local query = "SELECT skin FROM vr_clothing_skins WHERE citizenid = ?"
    local queryArgs = {citizenID}
    if model ~= nil then
        query = query .. " AND model = ?"
        queryArgs[#queryArgs + 1] = model
    else
        query = query .. " AND active = ?"
        queryArgs[#queryArgs + 1] = 1
    end
    return MySQL.scalar.await(query, queryArgs)
end

function Database.PlayerSkins.DeleteByCitizenID(citizenID)
    MySQL.query.await("DELETE FROM vr_clothing_skins WHERE citizenid = ?", { citizenID })
end

function Database.PlayerSkins.GetAll()
    return MySQL.query.await("SELECT * FROM vr_clothing_skins")
end
