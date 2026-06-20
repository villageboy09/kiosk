-- Create retailer_partners table
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
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Add referred_by_retailer_id to users
ALTER TABLE `users` ADD COLUMN `referred_by_retailer_id` INT DEFAULT NULL;
ALTER TABLE `users` ADD CONSTRAINT `fk_users_referred_by_retailer` FOREIGN KEY (`referred_by_retailer_id`) REFERENCES `retailer_partners`(`id`) ON DELETE SET NULL;

-- Add acreage column to user_crop_selections to support crop cultivation intelligence
ALTER TABLE `user_crop_selections` ADD COLUMN `acreage` DECIMAL(5, 2) DEFAULT 1.00;

-- Create retailer_leads table
CREATE TABLE IF NOT EXISTS `retailer_leads` (
  `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
  `farmer_identified_problem_id` INT NOT NULL,
  `retailer_partner_id` INT NOT NULL,
  `lead_status` ENUM('NEW', 'CONTACTED', 'VISITED', 'RESOLVED', 'CLOSED') NOT NULL DEFAULT 'NEW',
  `retailer_notes` TEXT DEFAULT NULL,
  `assigned_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_leads_identified_problem` FOREIGN KEY (`farmer_identified_problem_id`) REFERENCES `farmer_identified_problems`(`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_leads_retailer_partner` FOREIGN KEY (`retailer_partner_id`) REFERENCES `retailer_partners`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create extension_officers table
CREATE TABLE IF NOT EXISTS `extension_officers` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `name` VARCHAR(150) NOT NULL,
  `contact_number` VARCHAR(20) NOT NULL UNIQUE,
  `email` VARCHAR(100) DEFAULT NULL,
  `organization` VARCHAR(150) DEFAULT NULL,
  `coverage_mandal` VARCHAR(100) DEFAULT NULL,
  `coverage_district` VARCHAR(100) DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create outbreak_alerts table
CREATE TABLE IF NOT EXISTS `outbreak_alerts` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `crop_id` INT NOT NULL,
  `problem_id` INT NOT NULL,
  `district` VARCHAR(100) NOT NULL,
  `mandal` VARCHAR(100) NOT NULL,
  `village` VARCHAR(100) DEFAULT NULL,
  `outbreak_status` ENUM('DETECTED', 'INVESTIGATING', 'CONFIRMED', 'RESOLVED') NOT NULL DEFAULT 'DETECTED',
  `reports_count` INT NOT NULL DEFAULT 1,
  `triggered_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `resolved_at` DATETIME DEFAULT NULL,
  CONSTRAINT `fk_outbreaks_crop` FOREIGN KEY (`crop_id`) REFERENCES `crops`(`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_outbreaks_problem` FOREIGN KEY (`problem_id`) REFERENCES `rice_problems`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
