CREATE TABLE IF NOT EXISTS `vr_inventory_stashes` (
    `owner` varchar(60) NOT NULL DEFAULT '',
    `name` varchar(100) NOT NULL,
    `data` longtext DEFAULT NULL,
    `lastupdated` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
    UNIQUE KEY `owner_name` (`owner`, `name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `vr_inventory_stashes` (owner, name, data, lastupdated)
SELECT IFNULL(owner, ''), name, data, lastupdated FROM `ox_inventory`;
