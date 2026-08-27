-- =========================================================
-- CropSync Multi-Role Database Schema Migration
-- Supports: Farmer, Content Creator, CHC Operator, Retailer, Extension Officer
-- =========================================================

-- 1. Add role & auth fields to users table
ALTER TABLE `users` 
  ADD COLUMN IF NOT EXISTS `role` VARCHAR(50) NOT NULL DEFAULT 'farmer',
  ADD COLUMN IF NOT EXISTS `membership_type` VARCHAR(50) DEFAULT 'Farmer',
  ADD COLUMN IF NOT EXISTS `email` VARCHAR(150) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `password_hash` VARCHAR(255) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `security_question` VARCHAR(100) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `security_answer` VARCHAR(255) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `is_verified` TINYINT(1) DEFAULT 1;

-- Ensure index on role
ALTER TABLE `users` ADD INDEX IF NOT EXISTS `idx_users_role` (`role`);

-- 2. Ensure creators table has proper structure & user_id linkage
CREATE TABLE IF NOT EXISTS `creators` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `user_id` VARCHAR(50) NULL,
  `username` VARCHAR(100) NOT NULL UNIQUE,
  `display_name` VARCHAR(150) NOT NULL,
  `profile_image_url` VARCHAR(500) NULL,
  `is_verified` TINYINT(1) DEFAULT 1,
  `phone_number` VARCHAR(20) NULL,
  `email` VARCHAR(150) DEFAULT NULL,
  `bio` TEXT NULL,
  `followers_count` INT DEFAULT 0,
  `following_count` INT DEFAULT 0,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_creator_phone` (`phone_number`),
  INDEX `idx_creator_username` (`username`),
  INDEX `idx_creator_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Add user_id to creators if missing in existing table
ALTER TABLE `creators` 
  ADD COLUMN IF NOT EXISTS `user_id` VARCHAR(50) NULL,
  ADD COLUMN IF NOT EXISTS `email` VARCHAR(150) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `followers_count` INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS `following_count` INT DEFAULT 0;

-- 3. Ensure retailer_partners table exists
CREATE TABLE IF NOT EXISTS `retailer_partners` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `shop_name` VARCHAR(150) NOT NULL,
  `owner_name` VARCHAR(150) NOT NULL,
  `contact_number` VARCHAR(20) NOT NULL UNIQUE,
  `email` VARCHAR(100) DEFAULT NULL,
  `logo_url` VARCHAR(255) DEFAULT NULL,
  `latitude` DECIMAL(10, 7) DEFAULT NULL,
  `longitude` DECIMAL(10, 7) DEFAULT NULL,
  `village` VARCHAR(100) DEFAULT NULL,
  `mandal` VARCHAR(100) DEFAULT NULL,
  `district` VARCHAR(100) DEFAULT NULL,
  `region` VARCHAR(100) DEFAULT NULL,
  `tier` ENUM('BRONZE', 'SILVER', 'GOLD', 'PLATINUM') NOT NULL DEFAULT 'BRONZE',
  `subscription_status` ENUM('ACTIVE', 'INACTIVE') NOT NULL DEFAULT 'ACTIVE',
  `subscription_expires_at` DATETIME DEFAULT NULL,
  `referral_code` VARCHAR(50) NOT NULL UNIQUE,
  `client_code` VARCHAR(50) DEFAULT 'HYD001',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_retailer_contact` (`contact_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. Ensure extension_officers table exists
CREATE TABLE IF NOT EXISTS `extension_officers` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `name` VARCHAR(150) NOT NULL,
  `contact_number` VARCHAR(20) NOT NULL UNIQUE,
  `email` VARCHAR(100) DEFAULT NULL,
  `organization` VARCHAR(150) DEFAULT NULL,
  `coverage_mandal` VARCHAR(100) DEFAULT NULL,
  `coverage_district` VARCHAR(100) DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_officer_contact` (`contact_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5. Ensure chc_operators table has required indexes
ALTER TABLE `chc_operators` ADD INDEX IF NOT EXISTS `idx_operator_phone` (`phone_number`);
