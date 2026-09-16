# Handoff Report: Web Admin Management Dashboard Survey (`studio_dashboard.php`)

**Explorer**: Explorer 2 (Web Admin Dashboard Explorer)  
**Target File**: `c:\Users\reddy\Downloads\Projects\cropsync\studio_dashboard.php`  
**Working Directory**: `c:\Users\reddy\Downloads\Projects\cropsync\.agents\explorer_survey_2`  
**Date**: 2026-09-15  

---

## 1. Observation

### 1.1 Existing Architecture & File Inventory
- **Target File**: `c:\Users\reddy\Downloads\Projects\cropsync\studio_dashboard.php` (2,495 lines, 117,921 bytes).
- **PHP Syntax Check**: `php -l studio_dashboard.php` passed with `No syntax errors detected in studio_dashboard.php`.
- **Database Connection & Shared Config**:
  - `studio_dashboard.php` lines 13–45 loads `config.php` (or `../config.php`) and establishes a PDO connection with Indian Standard Time (`SET time_zone = '+05:30'`).
  - Line 29–31: Default credentials fallback: `username: u893187665_arjun`, `dbname: u893187665_kiosk`.
- **Styling & Frontend Libraries**:
  - Google Sans & Noto Sans Telugu typography (lines 667).
  - Phosphor Icons v2.1.1 (line 670).
  - Alpine.js v3.14.3 (line 673).
  - CSS Custom Properties (lines 678–700): `--bg: #fafafa`, `--surface: #ffffff`, `--border: #e4e4e7`, `--accent: #15803d`, `--danger: #dc2626`.

### 1.2 Current Dashboard Navigation & Views
Direct inspection of lines 1385–1397 reveals that `studio_dashboard.php` currently has **only three tabs**:
```html
1385:     <nav class="nav-tabs-bar">
1386:         <a href="?tab=news" class="tab-link <?= $activeTab === 'news' ? 'active' : '' ?>">
1387:             <i class="ph ph-newspaper"></i> Krishi News
1388:             <span class="tab-counter"><?= $totalNews ?></span>
1389:         </a>
1390:         <a href="?tab=reels" class="tab-link <?= $activeTab === 'reels' ? 'active' : '' ?>">
1391:             <i class="ph ph-film-strip"></i> Agri Reels
1392:             <span class="tab-counter"><?= $totalReels ?></span>
1393:         </a>
1394:         <a href="?tab=comments" class="tab-link <?= $activeTab === 'comments' ? 'active' : '' ?>">
1395:             <i class="ph ph-chat-centered-text"></i> Comments & Feedback
1396:         </a>
1397:     </nav>
```
1. **`?tab=news` (Krishi News)**:
   - Lists articles from `news_articles` table.
   - Search input (`#newsSearch`), category dropdown filter.
   - Bulk delete (`action=bulk_delete_news`), single delete (`action=delete_news`).
   - Toggle publishing status (`action=toggle_news_status`).
   - Article editor modal (`#newsModal`) supporting English, Telugu, Hindi with auto-translate via MyMemory API, cover image upload with XMLHttpRequest progress indicator.
2. **`?tab=reels` (Agri Reels)**:
   - Lists reels from `reels` table joined with `creators`.
   - Minimal table columns (lines 1588–1601): ID, Video, Caption & Tags, Creator, Audio, Visibility (`Active` / `Hidden`), Engagement, Date, Actions.
   - Actions: Edit reel, Play reel (`#reelPlayerModal`), Delete reel (`action=delete_reel`), Bulk delete (`action=bulk_delete_reels`), Toggle active visibility (`action=toggle_reel_status`).
   - Upload modal (`#reelModal`) with video upload via `?ajax_upload=video`.
3. **`?tab=comments` (Comments & Feedback)**:
   - Displays UNION of `news_article_comments` and `reel_comments` with single delete action (`action=delete_comment`).

### 1.3 Database Schema State in `studio_dashboard.php`
- In `studio_dashboard.php` (lines 52–148), table creation and alteration queries are executed inline on page load:
  - `news_articles` (id, title, summary, content, category, image_url, author, source_name, views_count, likes_count, comments_count, is_featured, status, published_at, created_at, updated_at).
  - `creators` (id, username, display_name, profile_image_url, is_verified, phone_number, bio, created_at).
  - `reels` (id, creator_id, video_url, caption, music_title, phone_number, tags, views_count, likes_count, saves_count, comments_count, is_active, created_at).
- **Missing Tables**: A repository-wide grep for `monthly_creator_payouts`, `payout_line_items`, `campaigns`, `campaign_creator_assignments`, `campaign_deliverables`, `reel_reviews`, and `audit_logs` returned **0 results**. None of these tables exist in `studio_dashboard.php` or `api/api.php` yet.
- **Missing Columns in `creators`**:
  - No `status` (`pending`, `active`, `rejected`, `suspended`).
  - No `partnership_tier` (`trial`, `active_partner`, `verified`, `strategic`).
  - No `niches`, `languages`, `youtube_handle`, `instagram_handle`, `facebook_handle`.
  - No `rejection_reason`, `approved_at`.
- **Missing Columns in `reels`**:
  - No `crop`, `category`, `language`, `source_url`, `original_content_date`, `rights_confirmed`.
  - No `is_duplicate`, `duplicate_of_reel_id`.
  - No moderation `status` (`draft`, `submitted`, `under_review`, `changes_requested`, `approved`, `rejected`).
  - No `rejection_reason_code` (`copyright`, `duplicate`, `misleading`, `low_quality`, `policy_violation`).
  - No `rejection_notes`, `reviewed_by`, `reviewed_at`.

---

## 2. Logic Chain

```
[Requirement R2 in ORIGINAL_REQUEST.md]
  │
  ├─ 1. Creator Onboarding Queue
  │    ├─ Observation: No creator review tab exists; `creators` table has only 8 basic columns.
  │    └─ Deduction: Need a dedicated 'creators' tab, applicant inspection card/table (social links, niches, rights timestamp),
  │                  approval/rejection forms, partnership tier selector, and strict 25-creator pilot cap check.
  │
  ├─ 2. Content Review Queue
  │    ├─ Observation: Current `reels` tab only toggles `is_active` (1/0) and lacks metadata fields (crop, category, source_url).
  │    └─ Deduction: Must upgrade to moderation queue with status filter, metadata inspector, duplicate source URL warning banner,
  │                  Approve/Request Changes/Reject buttons with 5 standardized reason codes, reviewer comments, and audit logging.
  │
  ├─ 3. Payout Centre
  │    ├─ Observation: Grep for 'payout' across codebase yields 0 results. Payout logic is entirely absent.
  │    └─ Deduction: Must implement deterministic monthly payout calculator applying exact specification rules:
  │                  0–4 reels: ₹0 | 5–9: ₹50 | 10–14: ₹100 | 15–19: ₹150 | 20–24: ₹225 | 25–29: ₹275 | 30+: ₹300.
  │                  Requires calendar month selector, bonus allocator, hold toggle, batch lock, finance approval,
  │                  CSV export endpoint, and mark-as-paid reconciliation modal.
  │
  ├─ 4. Campaign Management Hub
  │    ├─ Observation: No campaign tracking or commercial deliverable features exist in dashboard.
  │    └─ Deduction: Must create campaign CRUD, creator assignment with negotiated fee, proof URL review, and
  │                  campaign payout approval separate from base upload payouts.
  │
  └─ 5. Analytics & Audit Log
       ├─ Observation: No audit_logs table or leaderboard viewer exists.
       └─ Deduction: Must add KPI leaderboard (active creators vs 25 cap, submissions, approval rate, payout spend) and
                     immutable audit log table recording all administrative mutations.
```

---

## 3. Caveats
1. **Existing Features**: `studio_dashboard.php` currently contains production Krishi News management (with auto-translation) and basic reel uploading. All revamps must **preserve** existing Krishi News and basic reel functionality to avoid breaking current content operations.
2. **Database Engine**: The database is MySQL InnoDB running under PDO. Auto-migration statements must check for existing columns/tables safely using `SHOW TABLES LIKE` and `SHOW COLUMNS FROM` or `CREATE TABLE IF NOT EXISTS` to ensure non-destructive schema extension.
3. **Single File Architecture vs Modularization**: `studio_dashboard.php` is currently a monolithic script. Adding the required tabs inline preserves the single-entry deployment model used by CropSync's PHP infrastructure.
4. **Live Data & Testing**: Local testing can verify PHP syntax (`php -l`), SQL statement construction, and visual layout rendering, but cannot alter remote live databases without live connection credentials.

---

## 4. Conclusion & Gap Analysis Matrix

| Requirement Component | Current State in `studio_dashboard.php` | Required Changes |
| :--- | :--- | :--- |
| **Creator Onboarding Queue** | **Non-existent** | Add `?tab=creators` view; display pending applications, agricultural niches, languages, social handles, UPI profile, terms acceptance; approve/reject buttons; tier selector (`trial`, `active_partner`, `verified`, `strategic`); hard guardrail enforcing 25 active creator cap. |
| **Content Review Queue** | **Basic CRUD only** (no moderation states) | Add `?tab=moderation` (or revamp `?tab=reels`); add status pills (`submitted`, `under_review`, `approved`, `changes_requested`, `rejected`); video player preview; metadata display (crop, category, source URL, rights check); duplicate URL detection warning banner; Approve, Request Changes, Reject actions with 5 standardized reason codes; reviewer notes; write to `reel_reviews` and `audit_logs`. |
| **Payout Centre** | **Non-existent** | Add `?tab=payouts` view; calendar month selector; deterministic base payout calculator (0–4: ₹0, 5–9: ₹50, 10–14: ₹100, 15–19: ₹150, 20–24: ₹225, 25–29: ₹275, 30+: ₹300); bonus line item manager; exception/hold manager; batch lock; finance approval workflow; CSV export; mark-as-paid modal recording payment ref & date. |
| **Campaign Management Hub** | **Non-existent** | Add `?tab=campaigns` view; create brand campaigns (brand, budget, dates, deliverables); assign creators with negotiated fees; deliverable proof URL review & verification; approve campaign payouts as separate line items. |
| **Analytics & Audit Log** | **Non-existent** | Add `?tab=analytics` view; platform KPI cards (active creators vs 25 cap, monthly submissions, approval rate %, total payout spend); creator leaderboard; immutable audit log viewer tracking all admin actions. |
| **Database Auto-Migration** | Only migrates `news_articles`, basic `creators`, basic `reels` | Add auto-migration for `creator_terms`, `creator_payment_profiles`, `reel_reviews`, `monthly_creator_payouts`, `payout_line_items`, `campaigns`, `campaign_creator_assignments`, `campaign_deliverables`, `audit_logs`, plus new columns in `creators` and `reels`. |

---

## 5. Implementation Blueprint & Verification Method

### 5.1 Auto-Migration Schema to Inject
```sql
-- 1. Extend creators table
ALTER TABLE `creators` 
  ADD COLUMN IF NOT EXISTS `status` ENUM('pending', 'active', 'rejected', 'suspended') DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS `partnership_tier` ENUM('trial', 'active_partner', 'verified', 'strategic') DEFAULT 'trial',
  ADD COLUMN IF NOT EXISTS `niches` VARCHAR(255) NULL,
  ADD COLUMN IF NOT EXISTS `languages` VARCHAR(255) NULL,
  ADD COLUMN IF NOT EXISTS `youtube_handle` VARCHAR(100) NULL,
  ADD COLUMN IF NOT EXISTS `instagram_handle` VARCHAR(100) NULL,
  ADD COLUMN IF NOT EXISTS `facebook_handle` VARCHAR(100) NULL,
  ADD COLUMN IF NOT EXISTS `rejection_reason` TEXT NULL,
  ADD COLUMN IF NOT EXISTS `approved_at` DATETIME NULL;

-- 2. Extend reels table
ALTER TABLE `reels` 
  ADD COLUMN IF NOT EXISTS `crop` VARCHAR(100) NULL,
  ADD COLUMN IF NOT EXISTS `category` VARCHAR(100) NULL,
  ADD COLUMN IF NOT EXISTS `language` VARCHAR(20) DEFAULT 'te',
  ADD COLUMN IF NOT EXISTS `source_url` VARCHAR(500) NULL,
  ADD COLUMN IF NOT EXISTS `original_content_date` DATE NULL,
  ADD COLUMN IF NOT EXISTS `rights_confirmed` TINYINT(1) DEFAULT 1,
  ADD COLUMN IF NOT EXISTS `is_duplicate` TINYINT(1) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS `duplicate_of_reel_id` INT NULL,
  ADD COLUMN IF NOT EXISTS `status` ENUM('draft', 'submitted', 'under_review', 'changes_requested', 'approved', 'rejected') DEFAULT 'submitted',
  ADD COLUMN IF NOT EXISTS `rejection_reason_code` ENUM('copyright', 'duplicate', 'misleading', 'low_quality', 'policy_violation', 'other') NULL,
  ADD COLUMN IF NOT EXISTS `rejection_notes` TEXT NULL,
  ADD COLUMN IF NOT EXISTS `reviewed_by` VARCHAR(100) NULL,
  ADD COLUMN IF NOT EXISTS `reviewed_at` DATETIME NULL;

-- 3. Create Supporting Tables
CREATE TABLE IF NOT EXISTS `creator_terms` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `creator_id` INT NOT NULL,
  `terms_version` VARCHAR(20) NOT NULL DEFAULT 'v1.0',
  `has_accepted_terms` TINYINT(1) NOT NULL DEFAULT 1,
  `has_accepted_rights` TINYINT(1) NOT NULL DEFAULT 1,
  `ip_address` VARCHAR(50) NULL,
  `accepted_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_terms_creator` (`creator_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `creator_payment_profiles` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `creator_id` INT NOT NULL,
  `payment_method` ENUM('upi', 'bank_transfer') DEFAULT 'upi',
  `upi_id` VARCHAR(100) NULL,
  `account_holder_name` VARCHAR(150) NULL,
  `bank_name` VARCHAR(100) NULL,
  `account_number` VARCHAR(50) NULL,
  `ifsc_code` VARCHAR(20) NULL,
  `is_verified` TINYINT(1) DEFAULT 0,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_pay_creator` (`creator_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `reel_reviews` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `reel_id` INT NOT NULL,
  `reviewer_username` VARCHAR(100) NOT NULL DEFAULT 'admin',
  `previous_status` VARCHAR(50) NULL,
  `new_status` VARCHAR(50) NOT NULL,
  `reason_code` VARCHAR(50) NULL,
  `reviewer_comments` TEXT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_review_reel` (`reel_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `monthly_creator_payouts` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `billing_month` VARCHAR(7) NOT NULL,
  `creator_id` INT NOT NULL,
  `partnership_tier` VARCHAR(50) NOT NULL,
  `approved_reels_count` INT DEFAULT 0,
  `base_payout` DECIMAL(10,2) DEFAULT 0.00,
  `bonus_payout` DECIMAL(10,2) DEFAULT 0.00,
  `campaign_payout` DECIMAL(10,2) DEFAULT 0.00,
  `total_payout` DECIMAL(10,2) DEFAULT 0.00,
  `status` ENUM('draft', 'calculated', 'locked', 'approved', 'paid') DEFAULT 'draft',
  `is_held` TINYINT(1) DEFAULT 0,
  `hold_reason` TEXT NULL,
  `payment_reference` VARCHAR(150) NULL,
  `payment_method` VARCHAR(50) NULL,
  `paid_at` DATETIME NULL,
  `paid_by` VARCHAR(100) NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY `uk_month_creator` (`billing_month`, `creator_id`),
  INDEX `idx_payout_month` (`billing_month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `payout_line_items` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `payout_id` INT NULL,
  `creator_id` INT NOT NULL,
  `billing_month` VARCHAR(7) NOT NULL,
  `item_type` ENUM('base_upload', 'bonus', 'campaign_deliverable', 'adjustment', 'deduction') NOT NULL,
  `description` VARCHAR(255) NOT NULL,
  `amount` DECIMAL(10,2) NOT NULL,
  `reference_id` VARCHAR(100) NULL,
  `created_by` VARCHAR(100) NOT NULL DEFAULT 'system',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_line_payout` (`payout_id`),
  INDEX `idx_line_creator_month` (`creator_id`, `billing_month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `campaigns` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `brand_name` VARCHAR(150) NOT NULL,
  `title` VARCHAR(255) NOT NULL,
  `description` TEXT NOT NULL,
  `deliverable_specs` TEXT NULL,
  `total_budget` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `start_date` DATE NOT NULL,
  `end_date` DATE NOT NULL,
  `status` ENUM('draft', 'active', 'paused', 'completed', 'cancelled') DEFAULT 'draft',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `campaign_creator_assignments` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `campaign_id` INT NOT NULL,
  `creator_id` INT NOT NULL,
  `assigned_deliverables_count` INT NOT NULL DEFAULT 1,
  `negotiated_fee` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `status` ENUM('assigned', 'accepted', 'in_progress', 'submitted', 'completed', 'cancelled') DEFAULT 'assigned',
  `assigned_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY `uk_camp_creator` (`campaign_id`, `creator_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `campaign_deliverables` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `assignment_id` INT NOT NULL,
  `campaign_id` INT NOT NULL,
  `creator_id` INT NOT NULL,
  `deliverable_title` VARCHAR(255) NULL,
  `proof_url` VARCHAR(500) NOT NULL,
  `metrics_notes` TEXT NULL,
  `status` ENUM('pending_review', 'approved', 'changes_requested', 'rejected') DEFAULT 'pending_review',
  `reviewer_feedback` TEXT NULL,
  `payout_approved` TINYINT(1) DEFAULT 0,
  `submitted_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `reviewed_at` DATETIME NULL,
  INDEX `idx_deliv_assignment` (`assignment_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `audit_logs` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `actor_username` VARCHAR(100) NOT NULL DEFAULT 'admin',
  `action_type` VARCHAR(100) NOT NULL,
  `target_entity` VARCHAR(50) NOT NULL,
  `entity_id` INT NULL,
  `details` TEXT NULL,
  `ip_address` VARCHAR(50) NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_audit_action` (`action_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 5.2 Deterministic Monthly Payout Calculation Algorithm
```php
function calculateMonthlyBasePayout(int $approvedEligibleReels): float {
    if ($approvedEligibleReels < 5) {
        return 0.00;
    } elseif ($approvedEligibleReels < 10) {
        return 50.00;
    } elseif ($approvedEligibleReels < 15) {
        return 100.00;
    } elseif ($approvedEligibleReels < 20) {
        return 150.00;
    } elseif ($approvedEligibleReels < 25) {
        return 225.00;
    } elseif ($approvedEligibleReels < 30) {
        return 275.00;
    } else {
        return 300.00; // Cap at ₹300 for 30+ approved reels
    }
}
```

### 5.3 Verification Method
1. **PHP Syntax Validation**:
   ```powershell
   php -l studio_dashboard.php
   ```
   *Expected*: `No syntax errors detected in studio_dashboard.php`.
2. **Tab Rendering Spot-Check**:
   - `?tab=creators`: Renders creator onboarding queue with pilot cap counter (`X / 25`).
   - `?tab=moderation`: Renders interactive moderation queue with reason codes and duplicate URL warnings.
   - `?tab=payouts`: Renders monthly payout calculator, bonus lines, hold flags, batch lock, and CSV export.
   - `?tab=campaigns`: Renders brand campaigns, creator deliverables, and proof URLs.
   - `?tab=analytics`: Renders platform KPI leaderboard and immutable audit logs.
   - `?tab=news`: Retains full article editing and auto-translation features.
3. **Invalidation Conditions**:
   - Allowing approval of more than 25 active creators.
   - Counting duplicate source URL submissions towards monthly payout tiers.
   - Failing to record immutable audit log entries on moderation or payout actions.
   - Allowing unapproved or held payouts to be reconciled as paid.
