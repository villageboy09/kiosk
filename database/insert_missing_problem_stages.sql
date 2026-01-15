-- ============================================================
-- SQL Script to Insert Missing problem_stages Mappings
-- For: Turmeric (crop_id=14) and Banana (crop_id=13)
-- ============================================================
-- 
-- ROOT CAUSE: The problem_stages table is missing entries that map
-- Turmeric problems (232-245) to Turmeric stages (37-41), and
-- Banana problems (205-231) to Banana stages (32-36).
--
-- This script creates the missing mappings based on agricultural
-- best practices for when each problem typically occurs.
-- ============================================================

-- ============================================================
-- TURMERIC (crop_id=14)
-- Stages: 37 (Sprouting), 38 (Vegetative), 39 (Rhizome Initiation), 
--         40 (Rhizome Development), 41 (Maturity)
-- Problems: 232-245
-- ============================================================

-- Rhizome Rot (232) - Occurs during rhizome development and maturity
INSERT INTO problem_stages (problem_id, stage_id) VALUES (232, 39);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (232, 40);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (232, 41);

-- Leaf Spot (233) - Occurs during vegetative and later stages
INSERT INTO problem_stages (problem_id, stage_id) VALUES (233, 38);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (233, 39);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (233, 40);

-- Leaf Blotch (234) - Occurs during vegetative stages
INSERT INTO problem_stages (problem_id, stage_id) VALUES (234, 38);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (234, 39);

-- Dry Rot / Fusarium (235) - Occurs during rhizome development and maturity
INSERT INTO problem_stages (problem_id, stage_id) VALUES (235, 39);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (235, 40);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (235, 41);

-- Shoot Borer (236) - Occurs from sprouting through vegetative
INSERT INTO problem_stages (problem_id, stage_id) VALUES (236, 37);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (236, 38);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (236, 39);

-- Thrips (237) - Occurs during vegetative stages
INSERT INTO problem_stages (problem_id, stage_id) VALUES (237, 38);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (237, 39);

-- Rhizome Fly (238) - Occurs during rhizome development
INSERT INTO problem_stages (problem_id, stage_id) VALUES (238, 39);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (238, 40);

-- Leaf Roller (239) - Occurs during vegetative stages
INSERT INTO problem_stages (problem_id, stage_id) VALUES (239, 38);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (239, 39);

-- Rhizome Scale (240) - Occurs during rhizome development and maturity
INSERT INTO problem_stages (problem_id, stage_id) VALUES (240, 40);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (240, 41);

-- Root Knot Nematodes (241) - Occurs from sprouting through development
INSERT INTO problem_stages (problem_id, stage_id) VALUES (241, 37);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (241, 38);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (241, 39);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (241, 40);

-- Iron Deficiency (242) - Occurs during vegetative stages
INSERT INTO problem_stages (problem_id, stage_id) VALUES (242, 38);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (242, 39);

-- Nitrogen Deficiency (243) - Occurs during vegetative and development
INSERT INTO problem_stages (problem_id, stage_id) VALUES (243, 38);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (243, 39);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (243, 40);

-- Potassium Deficiency (244) - Occurs during rhizome development
INSERT INTO problem_stages (problem_id, stage_id) VALUES (244, 39);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (244, 40);

-- Zinc Deficiency (245) - Occurs during vegetative stages
INSERT INTO problem_stages (problem_id, stage_id) VALUES (245, 38);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (245, 39);


-- ============================================================
-- BANANA (crop_id=13)
-- Stages: 32 (Planting), 33 (Vegetative), 34 (Shooting), 
--         35 (Bunch Development), 36 (Maturity)
-- Problems: 205-231
-- ============================================================

-- Corm/Rhizome Weevil (205) - Occurs from planting through vegetative
INSERT INTO problem_stages (problem_id, stage_id) VALUES (205, 32);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (205, 33);

-- Nematodes (206) - Occurs throughout crop cycle
INSERT INTO problem_stages (problem_id, stage_id) VALUES (206, 32);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (206, 33);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (206, 34);

-- Pseudostem Borer (207) - Occurs during vegetative and shooting
INSERT INTO problem_stages (problem_id, stage_id) VALUES (207, 33);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (207, 34);

-- Banana Aphids (208) - Occurs during vegetative stages
INSERT INTO problem_stages (problem_id, stage_id) VALUES (208, 33);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (208, 34);

-- Fruit Rust Thrips (209) - Occurs during bunch development and maturity
INSERT INTO problem_stages (problem_id, stage_id) VALUES (209, 35);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (209, 36);

-- Lace Wing Bug (210) - Occurs during vegetative and shooting
INSERT INTO problem_stages (problem_id, stage_id) VALUES (210, 33);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (210, 34);

-- Fruit Scarring Beetle (211) - Occurs during bunch development
INSERT INTO problem_stages (problem_id, stage_id) VALUES (211, 35);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (211, 36);

-- Mealybugs (212) - Occurs during vegetative and later stages
INSERT INTO problem_stages (problem_id, stage_id) VALUES (212, 33);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (212, 34);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (212, 35);

-- Scale Insects (213) - Occurs during vegetative stages
INSERT INTO problem_stages (problem_id, stage_id) VALUES (213, 33);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (213, 34);

-- Panama Wilt / Fusarium (214) - Occurs from planting through vegetative
INSERT INTO problem_stages (problem_id, stage_id) VALUES (214, 32);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (214, 33);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (214, 34);

-- Erwinia Rot (215) - Occurs during vegetative and shooting
INSERT INTO problem_stages (problem_id, stage_id) VALUES (215, 33);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (215, 34);

-- Sigatoka Leaf Spot (216) - Occurs during vegetative and later
INSERT INTO problem_stages (problem_id, stage_id) VALUES (216, 33);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (216, 34);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (216, 35);

-- Bunchy Top Virus (217) - Occurs from planting through vegetative
INSERT INTO problem_stages (problem_id, stage_id) VALUES (217, 32);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (217, 33);

-- Bract Mosaic Virus (218) - Occurs during shooting and bunch development
INSERT INTO problem_stages (problem_id, stage_id) VALUES (218, 34);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (218, 35);

-- Heart Rot (219) - Occurs during vegetative stages
INSERT INTO problem_stages (problem_id, stage_id) VALUES (219, 33);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (219, 34);

-- Anthracnose (220) - Occurs during bunch development and maturity
INSERT INTO problem_stages (problem_id, stage_id) VALUES (220, 35);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (220, 36);

-- Cigar End Rot (221) - Occurs during bunch development and maturity
INSERT INTO problem_stages (problem_id, stage_id) VALUES (221, 35);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (221, 36);

-- Crown Rot (222) - Occurs during maturity
INSERT INTO problem_stages (problem_id, stage_id) VALUES (222, 36);

-- Finger Tip Rot (223) - Occurs during bunch development and maturity
INSERT INTO problem_stages (problem_id, stage_id) VALUES (223, 35);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (223, 36);

-- Phosphorus Deficiency (224) - Occurs during vegetative and development
INSERT INTO problem_stages (problem_id, stage_id) VALUES (224, 33);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (224, 34);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (224, 35);

-- Nitrogen Deficiency (225) - Occurs during vegetative stages
INSERT INTO problem_stages (problem_id, stage_id) VALUES (225, 33);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (225, 34);

-- Magnesium Deficiency (226) - Occurs during vegetative and bunch development
INSERT INTO problem_stages (problem_id, stage_id) VALUES (226, 33);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (226, 34);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (226, 35);

-- Potassium Deficiency (227) - Occurs during bunch development
INSERT INTO problem_stages (problem_id, stage_id) VALUES (227, 34);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (227, 35);

-- Boron Deficiency (228) - Occurs during shooting and bunch development
INSERT INTO problem_stages (problem_id, stage_id) VALUES (228, 34);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (228, 35);

-- Calcium Deficiency (229) - Occurs during bunch development
INSERT INTO problem_stages (problem_id, stage_id) VALUES (229, 35);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (229, 36);

-- Zinc Deficiency (230) - Occurs during vegetative stages
INSERT INTO problem_stages (problem_id, stage_id) VALUES (230, 33);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (230, 34);

-- Sulphur Deficiency (231) - Occurs during vegetative stages
INSERT INTO problem_stages (problem_id, stage_id) VALUES (231, 33);
INSERT INTO problem_stages (problem_id, stage_id) VALUES (231, 34);


-- ============================================================
-- VERIFICATION QUERIES (Run these after inserting to verify)
-- ============================================================

-- Check Turmeric problem_stages count
-- SELECT COUNT(*) as turmeric_mappings FROM problem_stages ps 
-- JOIN rice_problems rp ON ps.problem_id = rp.id 
-- WHERE rp.crop_id = 14;

-- Check Banana problem_stages count
-- SELECT COUNT(*) as banana_mappings FROM problem_stages ps 
-- JOIN rice_problems rp ON ps.problem_id = rp.id 
-- WHERE rp.crop_id = 13;

-- Test Turmeric stage 38 (Vegetative)
-- SELECT rp.id, rp.problem_name_en, rp.category 
-- FROM rice_problems rp 
-- JOIN problem_stages ps ON rp.id = ps.problem_id 
-- WHERE ps.stage_id = 38 AND rp.crop_id = 14;

-- Test Banana stage 33 (Vegetative)
-- SELECT rp.id, rp.problem_name_en, rp.category 
-- FROM rice_problems rp 
-- JOIN problem_stages ps ON rp.id = ps.problem_id 
-- WHERE ps.stage_id = 33 AND rp.crop_id = 13;
