local tables = {
    {
        name = 'vr_clothing_skins', old = 'playerskins',
        columns = 'id, citizenid, model, skin, active',
        create = [[CREATE TABLE IF NOT EXISTS `vr_clothing_skins` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `citizenid` varchar(255) NOT NULL,
            `model` varchar(255) NOT NULL,
            `skin` text NOT NULL,
            `active` tinyint(4) NOT NULL DEFAULT 1,
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`),
            KEY `active` (`active`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    },
    {
        name = 'vr_clothing_outfits', old = 'player_outfits',
        columns = 'id, citizenid, outfitname, model, props, components',
        create = [[CREATE TABLE IF NOT EXISTS `vr_clothing_outfits` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `citizenid` varchar(50) DEFAULT NULL,
            `outfitname` varchar(50) NOT NULL DEFAULT '0',
            `model` varchar(50) DEFAULT NULL,
            `props` varchar(1000) DEFAULT NULL,
            `components` varchar(1500) DEFAULT NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `citizenid_outfitname_model` (`citizenid`, `outfitname`, `model`),
            KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    },
    {
        name = 'vr_clothing_outfit_codes', old = 'player_outfit_codes',
        columns = 'id, outfitid, code',
        create = [[CREATE TABLE IF NOT EXISTS `vr_clothing_outfit_codes` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `outfitid` int(11) NOT NULL,
            `code` varchar(50) NOT NULL DEFAULT '',
            PRIMARY KEY (`id`),
            KEY `outfitid` (`outfitid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    },
    {
        name = 'vr_clothing_job_outfits', old = 'management_outfits',
        columns = 'id, job_name, type, minrank, name, gender, model, props, components',
        create = [[CREATE TABLE IF NOT EXISTS `vr_clothing_job_outfits` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `job_name` varchar(50) NOT NULL,
            `type` varchar(50) NOT NULL,
            `minrank` int(11) NOT NULL DEFAULT 0,
            `name` varchar(50) NOT NULL DEFAULT 'Cool Outfit',
            `gender` varchar(50) NOT NULL DEFAULT 'male',
            `model` varchar(50) DEFAULT NULL,
            `props` varchar(1000) DEFAULT NULL,
            `components` varchar(1500) DEFAULT NULL,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    },
}

local function exists(name)
    return tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?', { name })) == 1
end

local function count(name)
    return tonumber(MySQL.scalar.await(('SELECT COUNT(*) FROM `%s`'):format(name))) or 0
end

local function setup()
    for _, t in ipairs(tables) do
        MySQL.query.await(t.create)
        if exists(t.old) and count(t.name) == 0 then
            local moved = count(t.old)
            if moved > 0 then
                MySQL.query.await(('INSERT INTO `%s` (%s) SELECT %s FROM `%s`'):format(t.name, t.columns, t.columns, t.old))
                print(('^2[vr-clothing] copied %d rows from %s to %s. The old table was left as a backup.^0'):format(moved, t.old, t.name))
            end
        end
    end
end

local function run()
    local ok, err = pcall(setup)
    if not ok then print(('^1[vr-clothing] could not set up the clothing tables: %s^0'):format(tostring(err))) end
end

if MySQL.ready then MySQL.ready(run) else CreateThread(run) end
