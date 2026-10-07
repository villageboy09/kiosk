-- market_prices_fix.sql
-- Idempotent schema fix for market prices (safe to run more than once).
-- The API also self-heals the same changes on first request; run this to do it deliberately.
-- BACK UP the database first.

CREATE TABLE IF NOT EXISTS `market_prices_history` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `state` VARCHAR(100) NOT NULL,
  `district` VARCHAR(100) NOT NULL,
  `market` VARCHAR(150) NOT NULL,
  `commodity` VARCHAR(150) NOT NULL,
  `variety` VARCHAR(100) DEFAULT 'Other',
  `grade` VARCHAR(50) DEFAULT 'FAQ',
  `arrival_date` DATE NOT NULL,
  `min_price` DECIMAL(10,2) DEFAULT 0,
  `max_price` DECIMAL(10,2) DEFAULT 0,
  `modal_price` DECIMAL(10,2) DEFAULT 0,
  `source` VARCHAR(16) NOT NULL DEFAULT 'gov',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY `uniq_entry` (`state`, `district`, `market`, `commodity`, `variety`, `arrival_date`),
  INDEX `idx_state_dist` (`state`, `district`),
  INDEX `idx_comm_date` (`commodity`, `arrival_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Add `source` only if missing. Existing rows get 'legacy' (written before this fix, unverified);
-- new rows default to 'gov'. Real upstream rows overwrite a matching legacy row and flip it to 'gov'.
SET @has_source := (SELECT COUNT(*) FROM information_schema.COLUMNS
                    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_prices_history' AND COLUMN_NAME = 'source');
SET @sql := IF(@has_source = 0,
  "ALTER TABLE `market_prices_history` ADD COLUMN `source` VARCHAR(16) NOT NULL DEFAULT 'legacy'",
  'SELECT 1');
PREPARE s1 FROM @sql; EXECUTE s1; DEALLOCATE PREPARE s1;
-- Only switch the default when we just added the column (running this on its own is harmless).
SET @sql := IF(@has_source = 0,
  "ALTER TABLE `market_prices_history` ALTER COLUMN `source` SET DEFAULT 'gov'",
  'SELECT 1');
PREPARE s1 FROM @sql; EXECUTE s1; DEALLOCATE PREPARE s1;

-- Indexes (state, arrival_date)
SET @has_idx := (SELECT COUNT(*) FROM information_schema.STATISTICS
                 WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_prices_history' AND INDEX_NAME = 'idx_state_date');
SET @sql := IF(@has_idx = 0,
  'ALTER TABLE `market_prices_history` ADD INDEX `idx_state_date` (`state`, `arrival_date`)',
  'SELECT 1');
PREPARE s1 FROM @sql; EXECUTE s1; DEALLOCATE PREPARE s1;

-- Indexes (state, commodity, arrival_date)
SET @has_idx := (SELECT COUNT(*) FROM information_schema.STATISTICS
                 WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_prices_history' AND INDEX_NAME = 'idx_state_comm_date');
SET @sql := IF(@has_idx = 0,
  'ALTER TABLE `market_prices_history` ADD INDEX `idx_state_comm_date` (`state`, `commodity`, `arrival_date`)',
  'SELECT 1');
PREPARE s1 FROM @sql; EXECUTE s1; DEALLOCATE PREPARE s1;

-- Throttle log for on-demand upstream syncs (one attempt / 15 min / state)
CREATE TABLE IF NOT EXISTS `market_sync_log` (
  `state` VARCHAR(100) NOT NULL PRIMARY KEY,
  `last_attempt` DATETIME NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------------
-- Canonicalise stored `state` values (ONE-OFF, optional but recommended; the API reads `state IN (...)` for index use)
-- ---------------------------------------------------------------------------
-- WARNINGS: BACK UP FIRST. Changing `state` can violate uniq_entry (state, district, market, commodity, variety,
-- arrival_date) if a canonical-state row for the same key already exists; use UPDATE IGNORE (below) so such rows are
-- simply left as they are (they stay hidden/duplicated rather than failing the statement). Run the PREVIEW first.
-- The API still matches common spellings/case/leading-space variants even if you never run this.

-- PREVIEW: distinct stored state values that are not already clean (leading/trailing whitespace) with counts.
SELECT state, CHAR_LENGTH(state) AS len, COUNT(*) AS rows_n
FROM market_prices_history
GROUP BY state
ORDER BY state;

-- PREVIEW: rows whose state has stray whitespace.
SELECT state, COUNT(*) AS rows_n FROM market_prices_history
WHERE state <> TRIM(state) GROUP BY state;

-- Step 1 (commented): trim whitespace.
-- UPDATE IGNORE market_prices_history SET state = TRIM(state) WHERE state <> TRIM(state);

-- Step 2 (commented): canonicalise known spellings. Edit/extend the pairs to match what the PREVIEW shows.
-- Case differences need no rewrite (case-insensitive collation) but are normalised for tidiness.
-- UPDATE IGNORE market_prices_history SET state = 'NCT of Delhi'        WHERE TRIM(state) IN ('Delhi', 'New Delhi', 'NCT Delhi', 'delhi');
-- UPDATE IGNORE market_prices_history SET state = 'Chhattisgarh'        WHERE TRIM(state) IN ('Chattisgarh', 'Chhatisgarh', 'chattisgarh');
-- UPDATE IGNORE market_prices_history SET state = 'Uttarakhand'         WHERE TRIM(state) IN ('Uttrakhand', 'Uttaranchal');
-- UPDATE IGNORE market_prices_history SET state = 'Andaman and Nicobar' WHERE TRIM(state) IN ('Andaman and Nicobar Islands', 'Andaman & Nicobar Islands');
-- UPDATE IGNORE market_prices_history SET state = 'Puducherry'          WHERE TRIM(state) IN ('Pondicherry');
-- UPDATE IGNORE market_prices_history SET state = 'Telangana'           WHERE TRIM(state) IN ('Telengana', 'telangana', 'TELANGANA');
-- UPDATE IGNORE market_prices_history SET state = 'Andhra Pradesh'      WHERE TRIM(state) IN ('Andhra Pradesh ', 'andhra pradesh', 'ANDHRA PRADESH');
-- Afterwards re-run the first PREVIEW: every remaining value should be a canonical state name (rows that
-- UPDATE IGNORE skipped because of a key clash can be deleted or ignored; they are duplicates).

-- ---------------------------------------------------------------------------
-- Retention purge (OPTIONAL, commented out)
-- ---------------------------------------------------------------------------
-- The app only ever reads the last few days (trends: up to 90). Keeping ~120 days bounds table growth.
-- BACK UP first; check the count before deleting; for big tables delete in slices (add LIMIT 50000 and repeat).
-- SELECT COUNT(*) AS purge_candidates FROM market_prices_history WHERE arrival_date < CURDATE() - INTERVAL 120 DAY;
-- DELETE FROM market_prices_history WHERE arrival_date < CURDATE() - INTERVAL 120 DAY LIMIT 50000;
