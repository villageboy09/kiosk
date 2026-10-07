-- cleanup_fake_market_prices.sql
-- PREVIEW-FIRST cleanup of FAKE rows that the old getRealisticSeedMarketPrices() wrote into
-- market_prices_history (they were INSERT IGNOREd as if real).
--
-- !!! WARNINGS !!!
--  1. TAKE A FULL BACKUP of market_prices_history BEFORE DOING ANYTHING (mysqldump or CREATE TABLE ... AS SELECT).
--  2. Run market_prices_fix.sql first (adds the `source` column; pre-fix rows are labelled 'legacy').
--     Rows with source = 'gov' were written by the fixed code from real upstream data and are NEVER touched here.
--  3. Run ONLY the PREVIEW statements first. Read the counts and sample rows. Verify them by eye.
--  4. The DELETE statements are COMMENTED OUT on purpose. Uncomment one deliberately, run it inside the
--     transaction, check ROW_COUNT(), and only then COMMIT (otherwise ROLLBACK).
--  5. Run this whole script in ONE database session: the candidate list is a TEMPORARY TABLE.
--  6. Temp-table text columns and every text comparison carry an explicit COLLATE utf8mb4_unicode_ci to avoid
--     'Illegal mix of collations' (error 1267). If your main table uses another collation, it still works because
--     both sides of each comparison are COLLATEd explicitly (this makes those comparisons non-indexed; fine for a one-off).
--  7. The API hides source = 'legacy' rows by default (unless MARKET_SHOW_LEGACY=1), so you do not have to delete
--     legacy rows for users to stop seeing them; deleting is only housekeeping.
--
-- Seed pattern (read from the old generator before it was removed):
--   * 14 commodities with fixed variety and base price bands (min, max); each row used one random jitter
--     j in [-50, 50] for both ends:  min = base_min + j,  max = base_max + j,  modal = ROUND((min + max) / 2).
--   * grade always 'FAQ'.
--   * One fixed market per district: 8 Telangana (TS) or 6 Andhra Pradesh (AP) districts.
--   * TS districts were used for EVERY requested state except those containing "Andhra"; the state column was
--     just the requested name. So TS seed rows under any state that is not Telangana are definitely fake.
--   * arrival_date = the day of the request (any date).

DROP TEMPORARY TABLE IF EXISTS tmp_seed_commodities;
CREATE TEMPORARY TABLE tmp_seed_commodities (
  commodity VARCHAR(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  variety   VARCHAR(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  base_min  INT NOT NULL,
  base_max  INT NOT NULL
) DEFAULT CHARSET=utf8mb4 COLLATE utf8mb4_unicode_ci;
INSERT INTO tmp_seed_commodities (commodity, variety, base_min, base_max) VALUES
  ('Paddy(Dhan)(Common)', 'Common', 2250, 2360),
  ('Cotton', 'Medium Staple', 6900, 7450),
  ('Maize', 'Yellow', 2100, 2400),
  ('Chilli Red', 'Teja / Guntur', 14500, 18500),
  ('Tomato', 'Hybrid', 1800, 2800),
  ('Red Gram (Arhar/Tur)', 'Red', 7200, 7900),
  ('Groundnut', 'Pods with Shell', 5800, 6700),
  ('Soyabean', 'Yellow', 4300, 4850),
  ('Turmeric', 'Finger', 11000, 14800),
  ('Onion', 'Red', 1500, 2200),
  ('Bengal Gram(Gram)(Whole)', 'Desi', 5400, 6100),
  ('Green Gram (Moong)', 'Medium', 7600, 8400),
  ('Potato', 'Jyoti', 1600, 2100),
  ('Banana', 'Robusta', 1200, 1800);

DROP TEMPORARY TABLE IF EXISTS tmp_seed_markets;
CREATE TEMPORARY TABLE tmp_seed_markets (
  grp      VARCHAR(2) COLLATE utf8mb4_unicode_ci NOT NULL,
  district VARCHAR(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  market   VARCHAR(150) COLLATE utf8mb4_unicode_ci NOT NULL
) DEFAULT CHARSET=utf8mb4 COLLATE utf8mb4_unicode_ci;
INSERT INTO tmp_seed_markets (grp, district, market) VALUES
  ('TS', 'Hyderabad', 'Bowenpally'),
  ('TS', 'Warangal', 'Enumamula (Warangal)'),
  ('TS', 'Khammam', 'Khammam AMC'),
  ('TS', 'Karimnagar', 'Karimnagar AMC'),
  ('TS', 'Nizamabad', 'Nizamabad Yard'),
  ('TS', 'Suryapet', 'Suryapet Market'),
  ('TS', 'Mahabubnagar', 'Badepally'),
  ('TS', 'Nalgonda', 'Nalgonda AMC'),
  ('AP', 'Guntur', 'Guntur Yard'),
  ('AP', 'Kurnool', 'Kurnool Market'),
  ('AP', 'Krishna', 'Vijayawada AMC'),
  ('AP', 'East Godavari', 'Rajahmundry'),
  ('AP', 'Anantapur', 'Tadipatri'),
  ('AP', 'Chittoor', 'Tirupati AMC');

-- Candidates = rows matching the COMPLETE seed fingerprint (district+market pair, commodity+variety pair, grade FAQ,
-- price bands, identical jitter on min and max, modal = rounded midpoint) and still labelled source = 'legacy'.
-- tier:
--   A_ts_pair_under_other_state : TS district/market under a state that is not Telangana  -> certainly fake
--   B_state_label_matches_seed  : TS pair under Telangana, or AP pair under Andhra Pradesh -> very likely fake, but the
--                                  same states also hold REAL data, so review samples before deleting
--   C_other                     : AP pair under a non-Andhra state; shown for review only, never deleted here
DROP TEMPORARY TABLE IF EXISTS tmp_seed_candidates;
CREATE TEMPORARY TABLE tmp_seed_candidates (
  id INT NOT NULL PRIMARY KEY,
  tier VARCHAR(40) COLLATE utf8mb4_unicode_ci NOT NULL
) DEFAULT CHARSET=utf8mb4 COLLATE utf8mb4_unicode_ci;
INSERT INTO tmp_seed_candidates (id, tier)
SELECT h.id,
  CASE
    WHEN m.grp = 'TS' AND LOWER(h.state) NOT LIKE 'tel%ngana%' THEN 'A_ts_pair_under_other_state'
    WHEN m.grp = 'TS' AND LOWER(h.state) LIKE 'tel%ngana%'     THEN 'B_state_label_matches_seed'
    WHEN m.grp = 'AP' AND LOWER(h.state) LIKE 'andhra%'        THEN 'B_state_label_matches_seed'
    ELSE 'C_other'
  END
FROM market_prices_history h
JOIN tmp_seed_markets m
  ON LOWER(TRIM(h.district)) COLLATE utf8mb4_unicode_ci = LOWER(m.district) COLLATE utf8mb4_unicode_ci
 AND LOWER(TRIM(h.market))   COLLATE utf8mb4_unicode_ci = LOWER(m.market)   COLLATE utf8mb4_unicode_ci
JOIN tmp_seed_commodities c
  ON LOWER(TRIM(h.commodity)) COLLATE utf8mb4_unicode_ci = LOWER(c.commodity) COLLATE utf8mb4_unicode_ci
 AND LOWER(TRIM(h.variety))   COLLATE utf8mb4_unicode_ci = LOWER(c.variety)   COLLATE utf8mb4_unicode_ci
WHERE h.source = 'legacy'
  AND UPPER(TRIM(h.grade)) COLLATE utf8mb4_unicode_ci = 'FAQ'
  AND h.min_price BETWEEN c.base_min - 50 AND c.base_min + 50
  AND (h.max_price - c.base_max) = (h.min_price - c.base_min)
  AND h.modal_price = ROUND((h.min_price + h.max_price) / 2);

-- ============================ PREVIEW (read-only) ============================

-- P1. Where do the rows come from? ('legacy' = written before the fix; 'gov' = real, written by fixed code)
SELECT source, COUNT(*) AS rows_n, MIN(arrival_date) AS first_date, MAX(arrival_date) AS last_date
FROM market_prices_history GROUP BY source;

-- P2. How many suspected seed rows per tier?
SELECT tier, COUNT(*) AS rows_n FROM tmp_seed_candidates GROUP BY tier;

-- P3. Candidates by state label and tier
SELECT h.state, k.tier, COUNT(*) AS rows_n, MIN(h.arrival_date) AS first_date, MAX(h.arrival_date) AS last_date
FROM tmp_seed_candidates k JOIN market_prices_history h ON h.id = k.id
GROUP BY h.state, k.tier ORDER BY k.tier, rows_n DESC;

-- P4. Sample rows to eyeball (change the tier / LIMIT as needed)
SELECT k.tier, h.id, h.state, h.district, h.market, h.commodity, h.variety, h.min_price, h.max_price, h.modal_price, h.arrival_date
FROM tmp_seed_candidates k JOIN market_prices_history h ON h.id = k.id
ORDER BY k.tier, h.state, h.arrival_date DESC LIMIT 100;

-- P5. A genuine-looking day for contrast: per (state, date) how many seed-pattern rows vs. all rows?
-- A seed day for a district has exactly the 14 seed commodities and nothing else for that market.
SELECT h.state, h.arrival_date, h.district, h.market,
       COUNT(*) AS rows_in_market_day,
       SUM(k.id IS NOT NULL) AS seed_pattern_rows
FROM market_prices_history h
JOIN tmp_seed_markets m ON LOWER(TRIM(h.district)) COLLATE utf8mb4_unicode_ci = LOWER(m.district) COLLATE utf8mb4_unicode_ci
                       AND LOWER(TRIM(h.market))   COLLATE utf8mb4_unicode_ci = LOWER(m.market)   COLLATE utf8mb4_unicode_ci
LEFT JOIN tmp_seed_candidates k ON k.id = h.id
WHERE h.source = 'legacy'
GROUP BY h.state, h.arrival_date, h.district, h.market
HAVING seed_pattern_rows > 0
ORDER BY seed_pattern_rows DESC LIMIT 100;
-- Interpretation: when seed_pattern_rows = 14 AND rows_in_market_day = 14 the market/day is entirely seed.
-- If rows_in_market_day is larger, real rows share that market/day: inspect before deleting tier B.

-- P6. Legacy rows with an arrival_date of 0000-00-00 / NULL-ish (bad parse by the old STR_TO_DATE insert).
SELECT COUNT(*) AS zero_date_rows FROM market_prices_history WHERE arrival_date < '2000-01-01';

-- ============================ DELETE (commented out) ============================
-- Only after: backup taken, previews reviewed, counts match what you expect.
-- Tier A (certainly fake):
--
-- START TRANSACTION;
-- DELETE h FROM market_prices_history h
--   JOIN tmp_seed_candidates k ON k.id = h.id
--  WHERE k.tier = 'A_ts_pair_under_other_state' AND h.source = 'legacy';
-- SELECT ROW_COUNT() AS deleted_tier_a;   -- must equal the tier A count from P2
-- -- COMMIT;     -- or ROLLBACK;
--
-- Tier B (likely fake; only after reviewing P4/P5 samples; consider restricting to a date range or a state):
--
-- START TRANSACTION;
-- DELETE h FROM market_prices_history h
--   JOIN tmp_seed_candidates k ON k.id = h.id
--  WHERE k.tier = 'B_state_label_matches_seed' AND h.source = 'legacy';
-- SELECT ROW_COUNT() AS deleted_tier_b;   -- must equal the tier B count from P2
-- -- COMMIT;     -- or ROLLBACK;
--
-- Tier C is never deleted by this script. Legacy rows that match no tier are kept (cannot be justified as seed).
