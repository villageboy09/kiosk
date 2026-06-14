-- Database migration to add English descriptions to CropStages table

-- 1. Add Description_en column if it does not exist
ALTER TABLE `CropStages` ADD COLUMN IF NOT EXISTS `Description_en` TEXT DEFAULT NULL AFTER `Description`;

-- 2. Populate English descriptions for CropStages
-- Paddy/Rice (crop_id = 1)
UPDATE `CropStages` SET `Description_en` = 'Seed germination and root initiation.' WHERE `StageID` = 1;
UPDATE `CropStages` SET `Description_en` = 'Seedlings emerge and establish in the nursery or field.' WHERE `StageID` = 2;
UPDATE `CropStages` SET `Description_en` = 'Multiple tillers emerge; active tillers form.' WHERE `StageID` = 3;
UPDATE `CropStages` SET `Description_en` = 'Stem elongates; rapid vegetative growth occurs.' WHERE `StageID` = 4;
UPDATE `CropStages` SET `Description_en` = 'Panicle begins to initiate at the stem apex.' WHERE `StageID` = 5;
UPDATE `CropStages` SET `Description_en` = 'Panicle is within the flag leaf; final leaf becomes visible.' WHERE `StageID` = 6;
UPDATE `CropStages` SET `Description_en` = 'Panicle emerges; flowering and pollination occur.' WHERE `StageID` = 7;
UPDATE `CropStages` SET `Description_en` = 'Grains develop and fill with starch.' WHERE `StageID` = 8;
UPDATE `CropStages` SET `Description_en` = 'Grains harden and change color; crop reaches maturity.' WHERE `StageID` = 9;

-- Cotton (crop_id = 2)
UPDATE `CropStages` SET `Description_en` = 'Seed germination and seedling establishment stage, typically 4–10 days.' WHERE `StageID` = 10;
UPDATE `CropStages` SET `Description_en` = 'Vegetative growth stage with leaf and stem development, leading to square formation.' WHERE `StageID` = 11;
UPDATE `CropStages` SET `Description_en` = 'Squares continue developing; flowers start blooming.' WHERE `StageID` = 12;
UPDATE `CropStages` SET `Description_en` = 'Rapid flowering and boll formation; critical stage requiring nutrients and water.' WHERE `StageID` = 13;
UPDATE `CropStages` SET `Description_en` = 'Boll maturation begins; fibers and seeds develop inside the bolls.' WHERE `StageID` = 14;
UPDATE `CropStages` SET `Description_en` = 'Number of open bolls increases; plant transitions to mature stage.' WHERE `StageID` = 15;
UPDATE `CropStages` SET `Description_en` = 'Bolls fully open, lint dries, crop is ready for harvest.' WHERE `StageID` = 16;

-- Sunflower (crop_id = 12)
UPDATE `CropStages` SET `Description_en` = 'Seedling emergence stage after sowing seeds.' WHERE `StageID` = 26;
UPDATE `CropStages` SET `Description_en` = 'Rapid growth of leaves and stems (Vegetative Growth).' WHERE `StageID` = 27;
UPDATE `CropStages` SET `Description_en` = 'Flower bud (Star bud) starts forming.' WHERE `StageID` = 28;
UPDATE `CropStages` SET `Description_en` = 'Flower fully blooms (Ray florets open).' WHERE `StageID` = 29;
UPDATE `CropStages` SET `Description_en` = 'Flowers wither and seeds form and harden.' WHERE `StageID` = 30;
UPDATE `CropStages` SET `Description_en` = 'Back of the flower head turns yellow; ready for harvest.' WHERE `StageID` = 31;

-- Banana (crop_id = 13)
UPDATE `CropStages` SET `Description_en` = 'Root system development phase after planting suckers.' WHERE `StageID` = 32;
UPDATE `CropStages` SET `Description_en` = 'Rapid leaf growth stage (up to about 5-6 months).' WHERE `StageID` = 33;
UPDATE `CropStages` SET `Description_en` = 'Flower bunch emerges from the center of the plant.' WHERE `StageID` = 34;
UPDATE `CropStages` SET `Description_en` = 'Fruits form and increase in size and weight.' WHERE `StageID` = 35;
UPDATE `CropStages` SET `Description_en` = 'Fruits fully develop and become ready for harvest.' WHERE `StageID` = 36;

-- Turmeric (crop_id = 14)
UPDATE `CropStages` SET `Description_en` = 'Seed rhizomes sprout after planting.' WHERE `StageID` = 37;
UPDATE `CropStages` SET `Description_en` = 'Leaves grow rapidly, and the plant becomes bushy.' WHERE `StageID` = 38;
UPDATE `CropStages` SET `Description_en` = 'Sucker rhizomes begin to form underground.' WHERE `StageID` = 39;
UPDATE `CropStages` SET `Description_en` = 'Critical stage where rhizomes thicken and develop.' WHERE `StageID` = 40;
UPDATE `CropStages` SET `Description_en` = 'Leaves turn yellow and dry up; crop is ready for harvest.' WHERE `StageID` = 41;

-- Maize (crop_id = 17)
UPDATE `CropStages` SET `Description_en` = 'Seeds sprout and small plants appear above ground. Strong root establishment is critical.' WHERE `StageID` = 42;
UPDATE `CropStages` SET `Description_en` = 'Leaves and stems grow rapidly. Fertilizer and weed control are crucial.' WHERE `StageID` = 43;
UPDATE `CropStages` SET `Description_en` = 'Tassels emerge at the top, and silk appears on the cob. Pollination occurs; critical for yield.' WHERE `StageID` = 44;
UPDATE `CropStages` SET `Description_en` = 'Kernels form and fill in the cob, developing from milk stage to dough stage.' WHERE `StageID` = 45;
UPDATE `CropStages` SET `Description_en` = 'Black layer appears at the base of the kernel. Grain filling is complete.' WHERE `StageID` = 46;
UPDATE `CropStages` SET `Description_en` = 'Grain moisture decreases and the crop is ready for harvest.' WHERE `StageID` = 47;

-- Chilli (crop_id = 18)
UPDATE `CropStages` SET `Description_en` = 'Seeds sprout and small plants emerge above ground. Strong root establishment is critical.' WHERE `StageID` = 48;
UPDATE `CropStages` SET `Description_en` = 'Seedlings grow until they have 4-6 leaves. Proper watering and protection are required.' WHERE `StageID` = 49;
