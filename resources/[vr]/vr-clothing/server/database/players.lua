Database.Players = {}

function Database.Players.GetAll()
    return MySQL.query.await("SELECT * FROM vr_players")
end
