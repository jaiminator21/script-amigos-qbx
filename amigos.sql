-- ============================================================
--  Sistema de Amigos (script-amigos-qbx)
--  Una fila por dirección de la amistad (A->B y B->A) para que
--  las consultas por `citizenid` sean directas e indexadas.
-- ============================================================

CREATE TABLE IF NOT EXISTS `player_friends` (
    `id`               INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid`        VARCHAR(64)  NOT NULL,
    `friend_citizenid` VARCHAR(64)  NOT NULL,
    `created_at`       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_friendship` (`citizenid`, `friend_citizenid`),
    KEY `idx_citizenid` (`citizenid`),
    KEY `idx_friend` (`friend_citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
