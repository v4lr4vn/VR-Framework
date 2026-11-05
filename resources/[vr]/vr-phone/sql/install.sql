-- vr-phone tables. The resource runs this file by itself on start (CREATE IF NOT EXISTS), so importing it by hand is optional.
-- Every statement must end with a semicolon at the end of a line.

CREATE TABLE IF NOT EXISTS `vr_ph_phones` (
  `phone_id`     VARCHAR(64)       NOT NULL,
  `owner_cid`    VARCHAR(64)       DEFAULT NULL,
  `number`       VARCHAR(20)       NOT NULL,
  `sim`          LONGTEXT          DEFAULT NULL,
  `pin_hash`     CHAR(64)          DEFAULT NULL,
  `pin_salt`     CHAR(16)          DEFAULT NULL,
  `pin_length`   TINYINT UNSIGNED  DEFAULT NULL,
  `fail_count`   SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `locked_until` INT UNSIGNED      NOT NULL DEFAULT 0,
  `created_at`   TIMESTAMP         NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`phone_id`),
  UNIQUE KEY `number` (`number`),
  KEY `owner_cid` (`owner_cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vr_ph_state` (
  `phone_id`   VARCHAR(64) NOT NULL,
  `battery`    FLOAT       NOT NULL DEFAULT 100,
  `updated_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`phone_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vr_ph_settings` (
  `phone_id`   VARCHAR(64) NOT NULL,
  `settings`   LONGTEXT    DEFAULT NULL,
  `layout`     LONGTEXT    DEFAULT NULL,
  `updated_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`phone_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vr_ph_contacts` (
  `id`        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `phone_id`  VARCHAR(64)  NOT NULL,
  `name`      VARCHAR(40)  NOT NULL,
  `number`    VARCHAR(20)  NOT NULL,
  `favourite` TINYINT(1)   NOT NULL DEFAULT 0,
  `blocked`   TINYINT(1)   NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `phone_number` (`phone_id`, `number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Every message, once. `pair` is the two numbers in order, so both sides read the same conversation.
-- `dropped` is a message the receiver blocked: only the sender still sees it.
CREATE TABLE IF NOT EXISTS `vr_ph_messages` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `pair`       VARCHAR(44)     NOT NULL,
  `sender`     VARCHAR(20)     NOT NULL,
  `recipient`  VARCHAR(20)     NOT NULL,
  `body`       VARCHAR(600)    NOT NULL,
  `dropped`    TINYINT(1)      NOT NULL DEFAULT 0,
  `created_at` INT UNSIGNED    NOT NULL,
  PRIMARY KEY (`id`),
  KEY `pair` (`pair`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- One row per phone number and conversation: the list in the Messages app.
CREATE TABLE IF NOT EXISTS `vr_ph_threads` (
  `number`     VARCHAR(20)     NOT NULL,
  `other`      VARCHAR(20)     NOT NULL,
  `last_id`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `last_body`  VARCHAR(120)    DEFAULT NULL,
  `last_at`    INT UNSIGNED    NOT NULL DEFAULT 0,
  `last_mine`  TINYINT(1)      NOT NULL DEFAULT 0,
  `unread`     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `cleared_id` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`number`, `other`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vr_ph_calls` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `number`     VARCHAR(20)  NOT NULL,
  `other`      VARCHAR(20)  NOT NULL,
  `direction`  TINYINT      NOT NULL,
  `result`     VARCHAR(12)  NOT NULL,
  `duration`   INT UNSIGNED NOT NULL DEFAULT 0,
  `seen`       TINYINT(1)   NOT NULL DEFAULT 1,
  `created_at` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  KEY `number` (`number`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vr_ph_voicemail` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `number`     VARCHAR(20)  NOT NULL,
  `sender`     VARCHAR(20)  NOT NULL,
  `body`       VARCHAR(300) NOT NULL,
  `heard`      TINYINT(1)   NOT NULL DEFAULT 0,
  `created_at` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  KEY `number` (`number`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vr_ph_albums` (
  `id`       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `phone_id` VARCHAR(64)  NOT NULL,
  `name`     VARCHAR(30)  NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `phone_name` (`phone_id`, `name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- A photo is a small JPEG kept as text (`data`) with a thumbnail, or a link (`url`) when a picture host is set up.
-- `deleted_at` is 0 for a normal photo and the time it was deleted for one in Recently deleted.
CREATE TABLE IF NOT EXISTS `vr_ph_media` (
  `id`         BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `phone_id`   VARCHAR(64)      NOT NULL,
  `kind`       VARCHAR(8)       NOT NULL DEFAULT 'photo',
  `data`       MEDIUMTEXT       DEFAULT NULL,
  `thumb`      MEDIUMTEXT       DEFAULT NULL,
  `url`        VARCHAR(400)     DEFAULT NULL,
  `width`      SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `height`     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `bytes`      INT UNSIGNED     NOT NULL DEFAULT 0,
  `favourite`  TINYINT(1)       NOT NULL DEFAULT 0,
  `album_id`   INT UNSIGNED     DEFAULT NULL,
  `source`     VARCHAR(8)       NOT NULL DEFAULT 'camera',
  `deleted_at` INT UNSIGNED     NOT NULL DEFAULT 0,
  `created_at` INT UNSIGNED     NOT NULL,
  PRIMARY KEY (`id`),
  KEY `phone` (`phone_id`, `deleted_at`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Notes. `body` is plain text.
CREATE TABLE IF NOT EXISTS `vr_ph_notes` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `phone_id`   VARCHAR(64)  NOT NULL,
  `title`      VARCHAR(80)  NOT NULL,
  `body`       TEXT         DEFAULT NULL,
  `pinned`     TINYINT(1)   NOT NULL DEFAULT 0,
  `created_at` INT UNSIGNED NOT NULL,
  `updated_at` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  KEY `phone` (`phone_id`, `pinned`, `updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Reminders and calendar events use the game's own date ('YYYY-MM-DD') and the minute of the day (0 to 1439).
-- `alert_at` is the moment the alert is due, in minutes since 2000-01-01 on the game clock. It is NULL when there is no alert.
-- `fired` is 1 once the alert was sent.
CREATE TABLE IF NOT EXISTS `vr_ph_reminders` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `phone_id`   VARCHAR(64)  NOT NULL,
  `title`      VARCHAR(120) NOT NULL,
  `note`       VARCHAR(300) DEFAULT NULL,
  `date`       CHAR(10)     DEFAULT NULL,
  `minute`     SMALLINT     DEFAULT NULL,
  `alert_at`   BIGINT       DEFAULT NULL,
  `fired`      TINYINT(1)   NOT NULL DEFAULT 0,
  `done`       TINYINT(1)   NOT NULL DEFAULT 0,
  `created_at` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  KEY `phone` (`phone_id`, `done`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vr_ph_events` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `phone_id`   VARCHAR(64)  NOT NULL,
  `title`      VARCHAR(120) NOT NULL,
  `place`      VARCHAR(120) DEFAULT NULL,
  `note`       VARCHAR(500) DEFAULT NULL,
  `date`       CHAR(10)     NOT NULL,
  `minute`     SMALLINT     DEFAULT NULL,
  `length`     SMALLINT     DEFAULT NULL,
  `colour`     TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `remind`     SMALLINT     DEFAULT NULL,
  `alert_at`   BIGINT       DEFAULT NULL,
  `fired`      TINYINT(1)   NOT NULL DEFAULT 0,
  `created_at` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  KEY `phone` (`phone_id`, `date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Mail accounts (name@ravenmail.io). The password and the recovery code are kept as salted SHA-256, like the PIN.
-- `vr_ph_mail_links` says which account a phone is signed in to (one per phone).
CREATE TABLE IF NOT EXISTS `vr_ph_mail_accounts` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `address`       VARCHAR(40)  NOT NULL,
  `name`          VARCHAR(60)  DEFAULT NULL,
  `pass_hash`     CHAR(64)     NOT NULL,
  `pass_salt`     CHAR(16)     NOT NULL,
  `recovery_hash` CHAR(64)     NOT NULL,
  `recovery_salt` CHAR(16)     NOT NULL,
  `fail_count`    SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `locked_until`  INT UNSIGNED NOT NULL DEFAULT 0,
  `created_at`    INT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `address` (`address`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vr_ph_mail_links` (
  `phone_id`   VARCHAR(64)  NOT NULL,
  `account_id` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`phone_id`),
  KEY `account` (`account_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Each account has its own copy of a message. `folder` is inbox, sent or trash.
CREATE TABLE IF NOT EXISTS `vr_ph_mail` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `account_id` INT UNSIGNED    NOT NULL,
  `folder`     VARCHAR(8)      NOT NULL,
  `was`        VARCHAR(8)      DEFAULT NULL,
  `from_addr`  VARCHAR(60)     NOT NULL,
  `from_name`  VARCHAR(60)     DEFAULT NULL,
  `to_addr`    VARCHAR(60)     NOT NULL,
  `subject`    VARCHAR(100)    NOT NULL,
  `body`       TEXT            DEFAULT NULL,
  `is_read`    TINYINT(1)      NOT NULL DEFAULT 0,
  `starred`    TINYINT(1)      NOT NULL DEFAULT 0,
  `created_at` INT UNSIGNED     NOT NULL,
  `trashed_at` INT UNSIGNED     NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `box` (`account_id`, `folder`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Wallet. A log of money sent and received with the phone, and payment requests between phone numbers.
-- `kind` in the log is 'sent' or 'received'. `status` of a request is open, paid, declined, cancelled or expired.
CREATE TABLE IF NOT EXISTS `vr_ph_wallet_log` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `phone_id`   VARCHAR(64)  NOT NULL,
  `kind`       VARCHAR(8)   NOT NULL,
  `amount`     INT UNSIGNED NOT NULL,
  `other`      VARCHAR(20)  NOT NULL,
  `note`       VARCHAR(80)  DEFAULT NULL,
  `created_at` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  KEY `phone` (`phone_id`, `id`),
  KEY `limit` (`phone_id`, `kind`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vr_ph_wallet_requests` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `from_phone`  VARCHAR(64)  NOT NULL,
  `from_number` VARCHAR(20)  NOT NULL,
  `to_phone`    VARCHAR(64)  NOT NULL,
  `to_number`   VARCHAR(20)  NOT NULL,
  `amount`      INT UNSIGNED NOT NULL,
  `note`        VARCHAR(80)  DEFAULT NULL,
  `status`      VARCHAR(10)  NOT NULL DEFAULT 'open',
  `created_at`  INT UNSIGNED NOT NULL,
  `closed_at`   INT UNSIGNED DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `payer` (`to_phone`, `status`),
  KEY `payee` (`from_phone`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Maps: places a player saved. The coordinates are game world coordinates.
CREATE TABLE IF NOT EXISTS `vr_ph_places` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `phone_id`   VARCHAR(64)  NOT NULL,
  `name`       VARCHAR(40)  NOT NULL,
  `x`          FLOAT        NOT NULL,
  `y`          FLOAT        NOT NULL,
  `z`          FLOAT        NOT NULL DEFAULT 0,
  `icon`       VARCHAR(12)  NOT NULL DEFAULT 'pin',
  `created_at` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  KEY `phone` (`phone_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Health: one row per phone per day ('YYYY-MM-DD' on the server's own calendar).
CREATE TABLE IF NOT EXISTS `vr_ph_health_days` (
  `phone_id`   VARCHAR(64)  NOT NULL,
  `day`        CHAR(10)     NOT NULL,
  `steps`      INT UNSIGNED NOT NULL DEFAULT 0,
  `metres`     INT UNSIGNED NOT NULL DEFAULT 0,
  `active`     INT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at` INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`phone_id`, `day`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Music: the songs (YouTube links) a phone has saved. Only the link's video id, the title and the length are kept, never any audio.
CREATE TABLE IF NOT EXISTS `vr_ph_music_tracks` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `phone_id`   VARCHAR(64)  NOT NULL,
  `video_id`   CHAR(11)     NOT NULL,
  `title`      VARCHAR(160) NOT NULL,
  `author`     VARCHAR(100) NOT NULL DEFAULT '',
  `seconds`    INT UNSIGNED NULL,
  `created_at` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `song` (`phone_id`, `video_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vr_ph_apps` (
  `phone_id`   VARCHAR(64) NOT NULL,
  `app_id`     VARCHAR(40) NOT NULL,
  `installed`  TINYINT(1)  NOT NULL DEFAULT 1,
  `paid`       TINYINT(1)  NOT NULL DEFAULT 0,
  `changed_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`phone_id`, `app_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vr_ph_veil_aliases` (
  `phone_id`   VARCHAR(64)  NOT NULL,
  `alias`      VARCHAR(16)  NOT NULL,
  `changed_at` INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`phone_id`),
  UNIQUE KEY `alias` (`alias`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vr_ph_veil_rooms` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`        VARCHAR(24)  NOT NULL,
  `topic`       VARCHAR(80)  DEFAULT NULL,
  `owner_phone` VARCHAR(64)  DEFAULT NULL,
  `pass_hash`   CHAR(64)     DEFAULT NULL,
  `pass_salt`   CHAR(16)     DEFAULT NULL,
  `builtin`     TINYINT(1)   NOT NULL DEFAULT 0,
  `created_at`  INT UNSIGNED NOT NULL,
  `last_at`     INT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vr_ph_veil_members` (
  `room_id`   INT UNSIGNED    NOT NULL,
  `phone_id`  VARCHAR(64)     NOT NULL,
  `last_read` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`room_id`, `phone_id`),
  KEY `phone_id` (`phone_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vr_ph_veil_messages` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `room_id`    INT UNSIGNED    DEFAULT NULL,
  `from_phone` VARCHAR(64)     NOT NULL,
  `to_phone`   VARCHAR(64)     DEFAULT NULL,
  `body`       VARCHAR(400)    NOT NULL,
  `created_at` INT UNSIGNED    NOT NULL,
  PRIMARY KEY (`id`),
  KEY `room` (`room_id`, `id`),
  KEY `dm_to` (`to_phone`, `from_phone`, `id`),
  KEY `dm_from` (`from_phone`, `to_phone`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vr_ph_veil_blocks` (
  `phone_id`      VARCHAR(64) NOT NULL,
  `blocked_phone` VARCHAR(64) NOT NULL,
  PRIMARY KEY (`phone_id`, `blocked_phone`),
  KEY `blocked_phone` (`blocked_phone`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vr_ph_veil_dmreads` (
  `phone_id`  VARCHAR(64)     NOT NULL,
  `peer_phone` VARCHAR(64)    NOT NULL,
  `last_read` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`phone_id`, `peer_phone`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vr_ph_hearth_profiles` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `phone_id`   VARCHAR(64)  NOT NULL,
  `name`       VARCHAR(20)  NOT NULL,
  `age`        TINYINT UNSIGNED NOT NULL,
  `gender`     TINYINT(1)   NOT NULL DEFAULT 0,
  `show_me`    TINYINT(1)   NOT NULL DEFAULT 2,
  `bio`        VARCHAR(240) DEFAULT NULL,
  `tags`       VARCHAR(160) DEFAULT NULL,
  `photos`     MEDIUMTEXT   DEFAULT NULL,
  `visible`    TINYINT(1)   NOT NULL DEFAULT 1,
  `created_at` INT UNSIGNED NOT NULL,
  `active_at`  INT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `phone_id` (`phone_id`),
  KEY `deck` (`visible`, `active_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vr_ph_hearth_swipes` (
  `phone_id`   VARCHAR(64)  NOT NULL,
  `target_id`  INT UNSIGNED NOT NULL,
  `liked`      TINYINT(1)   NOT NULL,
  `created_at` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`phone_id`, `target_id`),
  KEY `target` (`target_id`, `liked`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vr_ph_hearth_matches` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `a_id`       INT UNSIGNED NOT NULL,
  `b_id`       INT UNSIGNED NOT NULL,
  `a_read`     BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `b_read`     BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `created_at` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `pair` (`a_id`, `b_id`),
  KEY `b_id` (`b_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vr_ph_hearth_messages` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `match_id`   INT UNSIGNED    NOT NULL,
  `from_id`    INT UNSIGNED    NOT NULL,
  `body`       VARCHAR(400)    NOT NULL,
  `created_at` INT UNSIGNED    NOT NULL,
  PRIMARY KEY (`id`),
  KEY `match` (`match_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
