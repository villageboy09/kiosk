-- Migration: Add index to users phone_number column to optimize login search performance
ALTER TABLE `users` ADD INDEX `idx_users_phone_number` (`phone_number`);
