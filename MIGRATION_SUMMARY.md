# Supabase to MySQL Migration Summary

## Overview

This document summarizes the complete migration of the CropSync Kiosk Flutter app from Supabase backend to MySQL database with PHP API.

## Changes Made

### 1. New Files Created

| File | Description |
|------|-------------|
| `lib/models/user.dart` | User model class matching MySQL `users` table |
| `lib/services/api_service.dart` | HTTP service for all MySQL backend API calls |
| `lib/services/auth_service.dart` | Session management with SharedPreferences |
| `api/api.php` | PHP API file for server-side MySQL operations |

### 2. Files Modified

| File | Changes |
|------|---------|
| `lib/main.dart` | Removed Supabase initialization, uses AuthService |
| `lib/auth/login_screen.dart` | Login via MySQL API instead of Supabase Edge Function |
| `lib/screens/home_screen.dart` | Fetches user data from AuthService |
| `lib/screens/profile_screen.dart` | Displays user profile from AuthService |
| `lib/welcome_screen.dart` | Session check via AuthService |
| `lib/screens/settings_screen.dart` | Crop selections via MySQL API |
| `lib/screens/advisory_screen.dart` | Advisories and problems via MySQL API |
| `lib/screens/advisory_details.dart` | Advisory details via MySQL API |
| `lib/screens/agri_shop.dart` | Products via MySQL API |
| `lib/screens/product_details_screen.dart` | Purchase requests via MySQL API |
| `lib/screens/seed_varieties.dart` | Seed varieties via MySQL API |
| `pubspec.yaml` | Removed `supabase_flutter`, added `shared_preferences` |

### 3. Dependencies Changed

**Removed:**
- `supabase_flutter: ^2.8.4`

**Added:**
- `shared_preferences: ^2.2.2`

## API Endpoints

The PHP API (`api/api.php`) provides the following endpoints:

### Authentication
- `POST /api.php?action=login` - User login with user_id
- `GET /api.php?action=get_user&user_id=XXX` - Get user details

### Crops & Selections
- `GET /api.php?action=get_crops&lang=te` - Get all crops
- `GET /api.php?action=get_varieties&crop_id=X` - Get varieties for a crop
- `GET /api.php?action=get_user_selections&user_id=XXX&lang=te` - Get user's crop selections
- `POST /api.php?action=save_selection` - Save crop selection
- `PUT /api.php?action=update_selection` - Update crop selection
- `DELETE /api.php?action=delete_selection&id=X` - Delete crop selection

### Advisories
- `GET /api.php?action=get_crop_stages&crop_id=X&lang=te` - Get crop stages
- `GET /api.php?action=get_stage_duration&crop_id=X&variety_id=X` - Get stage durations
- `GET /api.php?action=get_problems&crop_id=X&stage_id=X&lang=te` - Get problems
- `GET /api.php?action=get_advisories&problem_id=X&lang=te` - Get advisories
- `GET /api.php?action=get_advisory_components&advisory_id=X&lang=te` - Get advisory components
- `POST /api.php?action=save_identified_problem` - Save identified problem

### Products
- `GET /api.php?action=get_products&lang=en&category=X&search=X&sort=X` - Get products
- `GET /api.php?action=get_product_categories&lang=en` - Get product categories
- `POST /api.php?action=save_purchase_request` - Save purchase request
- `POST /api.php?action=create_purchase_request` - Create purchase request with full details

### Seed Varieties
- `GET /api.php?action=get_seed_varieties&lang=te&crop_name=X` - Get seed varieties

## Deployment Instructions

### 1. Deploy PHP API

1. Upload `api/api.php` to your server at `https://kiosk.cropsync.in/api/api.php`
2. Update the database credentials in the PHP file:
   ```php
   $host = 'localhost';
   $dbname = 'u511597003_kiosk';
   $username = 'u511597003_kiosk';
   $password = 'YOUR_ACTUAL_PASSWORD';
   ```

### 2. Update Flutter App

1. Pull the latest changes from GitHub
2. Run `flutter pub get` to install new dependencies
3. Build and deploy the app

## How Authentication Works

1. User enters their 6-digit User ID (from `users.user_id` column)
2. App calls `POST https://kiosk.cropsync.in/api/login_api.php` with `{"user_id": "123456"}`
3. On success, user data is stored locally using SharedPreferences
4. User remains logged in until they explicitly logout

## Database Tables Used

- `users` - User authentication and profile
- `crops` - Crop master data
- `crop_varieties` - Crop varieties
- `user_crop_selections` - User's selected crops
- `crop_stages` - Growth stages for crops
- `crop_stage_durations` - Duration of each stage
- `crop_problems` - Problems/diseases for crops
- `crop_advisories` - Advisories for problems
- `advisory_recommendations` - Recommendations for advisories
- `farmer_identified_problems` - Problems identified by farmers
- `products` - Products for sale
- `advertisers` - Product advertisers
- `purchase_requests` - Purchase requests from users
- `seed_varieties` - Seed variety information

## GitHub Commits

1. **f2a60c1** - Initial migration: Replace Supabase with MySQL for user authentication
2. **300d2be** - Complete migration: Remove all Supabase instances from all screens

## Notes

- The existing `login_api.php` endpoint continues to work for authentication
- All new API endpoints are consolidated in `api/api.php`
- Multi-language support (English, Hindi, Telugu) is maintained through the `lang` parameter
- Session persistence is handled via SharedPreferences instead of Supabase Auth
