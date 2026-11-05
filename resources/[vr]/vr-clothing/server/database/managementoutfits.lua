Database.ManagementOutfits = {}

function Database.ManagementOutfits.GetAllByJob(type, jobName, gender)
    local query = "SELECT * FROM vr_clothing_job_outfits WHERE type = ? AND job_name = ?"
    local queryArgs = {type, jobName}

    if gender then
        query = query .. " AND gender = ?"
        queryArgs[#queryArgs + 1] = gender
    end

    return MySQL.query.await(query, queryArgs)
end

function Database.ManagementOutfits.Add(outfitData)
    return MySQL.insert.await("INSERT INTO vr_clothing_job_outfits (job_name, type, minrank, name, gender, model, props, components) VALUES (?, ?, ?, ?, ?, ?, ?, ?)", {
        outfitData.JobName,
        outfitData.Type,
        outfitData.MinRank,
        outfitData.Name,
        outfitData.Gender,
        outfitData.Model,
        json.encode(outfitData.Props),
        json.encode(outfitData.Components)
    })
end

function Database.ManagementOutfits.DeleteByID(id)
    MySQL.query.await("DELETE FROM vr_clothing_job_outfits WHERE id = ?", {id})
end
