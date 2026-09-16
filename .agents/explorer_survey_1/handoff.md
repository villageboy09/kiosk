# Backend & Database Schema Survey Report: Agri Creator Partner Program

**Author**: Explorer 1 (Backend & Schema Explorer)  
**Date**: 2026-09-15  
**Target File**: `c:\Users\reddy\Downloads\Projects\cropsync\.agents\explorer_survey_1\handoff.md`  
**Working Directory**: `c:\Users\reddy\Downloads\Projects\cropsync\.agents\explorer_survey_1`

---

## 1. Observation

### 1.1 Files Examined & Environment
- **`api/config.php`** (Lines 1–53): Defines database credentials (`u893187665_arjun` / `u893187665_kiosk`), establishes both MySQLi (`$conn`) and PDO (`$pdo`), forces `SET time_zone = '+05:30'`, and sets `GEMINI_API_KEY` and `CDN_URL`.
- **`api/api.php`** (Lines 1–5743): Primary REST API backend. Handles JSON and form requests via `switch ($action)` at line 463. Performs runtime schema migrations on boot (lines 38–454).
- **`api/reels.php`** (Lines 1–849): Standalone/legacy reels endpoint providing duplicate action routing (`studio`, `upload`, `like`, `save`, `comment`, `action`, `watch`). Contains runtime table creation for `reels`, `reel_likes`, `reel_comments`, `reel_actions`, `reel_watch_analytics`.
- **`api/fix_reels.php`** (Lines 1–253): Database repair script verifying and recreating missing primary keys and columns for `reels`, `creators`, `reel_likes`, `reel_comments`, `reel_actions`, `reel_watch_analytics`.
- **`studio_dashboard.php`** (Lines 1–2495): Web admin dashboard containing tabs for `news`, `reels`, and `comments`. Auto-migrates `news_articles`, `creators`, and `reels` tables at lines 51–148.
- **`database/u893187665_kiosk.sql`** (110,877 lines): Base phpMyAdmin SQL database dump. Notably lacks `creators`, `reels`, `campaigns`, `payouts`, or moderation tables in the static dump, relying entirely on runtime `CREATE TABLE IF NOT EXISTS` inside `api.php`, `reels.php`, and `studio_dashboard.php`.
- **`lib/services/creator_service.dart`** (Lines 1–612): Flutter client calling `api.php?action=get_creator_studio_data`, `api.php?action=upload_reel`, etc., with fallback to `reels.php`.
- **`test/creator_studio_test.dart`** (Lines 1–273): Unit and widget test suite for Creator Studio screens and models.

---

### 1.2 Table Inventory: Required vs Existing

| # | Required Table (`ORIGINAL_REQUEST.md` R3) | Status in Codebase | Existing Location | Missing Columns & Structural Deficiencies |
|---|---|---|---|---|
| 1 | `creators` | **Partially Exists** | `api/api.php:139-154`, `studio_dashboard.php:76-86` | Contains basic columns: `id`, `user_id`, `username`, `display_name`, `profile_image_url`, `is_verified`, `phone_number`, `email`, `bio`, `followers_count`, `following_count`, `created_at`.<br>**MISSING**: `status` (`applied`, `pending_review`, `active`, `rejected`, `suspended`), `tier` (`trial`, `active_partner`, `verified`, `strategic`), `agriculture_niches` (JSON), `languages` (JSON), `social_handles` (JSON), `reviewed_by`, `reviewed_at`, `rejection_reason`. |
| 2 | `creator_terms` | **MISSING** | Nowhere in codebase | Table does not exist. No audit trail for terms version, ownership declaration, or rights acceptance timestamp/IP. |
| 3 | `creator_payment_profiles` | **MISSING** | Nowhere in codebase | Table does not exist. No storage for UPI ID, bank account, IFSC, masking, or verification status. |
| 4 | `reels` | **Partially Exists** | `api/api.php:364-381`, `studio_dashboard.php:89-106` | Contains: `id`, `creator_id`, `video_url`, `caption`, `music_title`, `phone_number`, `tags`, `views_count`, `likes_count`, `saves_count`, `comments_count`, `is_active`, `created_at`.<br>**MISSING**: `crop`, `category`, `language`, `source_url`, `content_hash`, `original_content_date`, `rights_declared`, `status` (`draft`, `submitted`, `under_review`, `changes_requested`, `approved`, `rejected`), `payout_eligible`, `rejection_reason_code`, `reviewer_feedback`, `reviewed_at`, `reviewed_by`. |
| 5 | `reel_reviews` | **MISSING** | Nowhere in codebase | Table does not exist. Moderation actions, reviewer identity, review comments, and reason codes are completely untracked. |
| 6 | `reel_events` | **MISSING** | Nowhere in codebase | Only raw `reel_actions` (`save`, `call`, `share`) and `reel_watch_analytics` exist. Lacks unified event telemetry with privacy masking for farmer identities. |
| 7 | `monthly_creator_payouts` | **MISSING** | Nowhere in codebase | No table, schema, or records for calendar month payouts, base amount, approved reel count, bonus totals, lock status, approval, or UTR payment reconciliation. |
| 8 | `payout_line_items` | **MISSING** | Nowhere in codebase | Table does not exist. No itemized breakdown for base upload tiers, bonuses, campaign earnings, deductions, or adjustments. |
| 9 | `campaigns` | **MISSING** | Nowhere in codebase | Table does not exist. No commercial campaign management, budget tracking, or brand campaign metadata. |
| 10 | `campaign_creator_assignments`| **MISSING** | Nowhere in codebase | Table does not exist. No creator assignment, negotiated commercial fee, or assignment status tracking. |
| 11 | `campaign_deliverables` | **MISSING** | Nowhere in codebase | Table does not exist. No deliverable tracking, proof URL submission, deadline management, or separate campaign payout approval. |
| 12 | `leads` | **Partially Exists** (Retailer Only) | `api/api.php:3762` uses `retailer_leads` | Existing table `retailer_leads` only links farmers to agri-retailers for store visits/problems. **MISSING**: Creator-attributed leads/inquiries originating from reels with farmer identity protection. |
| 13 | `audit_logs` | **MISSING** | `database/u893187665_kiosk.sql` has legacy `admin_logs` | Unified immutable audit log for administrative decisions (creator approvals, moderation decisions, payout locks, finance approvals, payments) does not exist. |

---

### 1.3 Analysis of Existing Endpoints & Action Handlers

#### A. In `api/api.php` (Lines 650–696):
```php
// AGRI REELS & SHORT VIDEOS ENDPOINTS
case 'get_reels': getReels($pdo); break;
case 'toggle_reel_like': toggleReelLike($pdo); break;
case 'toggle_reel_save': toggleReelSave($pdo); break;
case 'get_reel_comments': case 'get_comments': case 'comments': getReelComments($pdo); break;
case 'add_reel_comment': case 'add_comment': case 'comment': addReelComment($pdo); break;
case 'log_reel_action': logReelAction($pdo); break;
case 'log_reel_watch': logReelWatch($pdo); break;
// CREATOR STUDIO & UPLOAD ENDPOINTS
case 'upload_reel': uploadReel($pdo); break;
case 'delete_reel': deleteReel($pdo); break;
case 'toggle_reel_status': toggleReelStatus($pdo); break;
case 'create_news_article': createNewsArticle($pdo); break;
case 'delete_news_article': deleteNewsArticle($pdo); break;
case 'toggle_news_status': toggleNewsStatus($pdo); break;
case 'get_creator_studio_data': getCreatorStudioData($pdo); break;
```

#### B. Creator Auto-Provisioning Flaw in `resolveOrCreateCreator` (`api/api.php:4714–4760`):
```php
function resolveOrCreateCreator($pdo, $phoneNumber = '', $name = '') {
    // ...
    // Auto-create creator
    $sanitizedUsername = ...;
    $displayName = !empty($name) ? $name : 'Agri Creator';
    $profileImage = 'https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&w=200&q=80';
    $bio = 'Progressive Farmer & Agricultural Contributor on CropSync';

    $insert = $pdo->prepare("INSERT INTO creators (username, display_name, profile_image_url, is_verified, phone_number, bio) VALUES (?, ?, ?, 1, ?, ?)");
    $insert->execute([$sanitizedUsername, $displayName, $profileImage, $phoneNumber, $bio]);
    // ...
}
```
*Direct Observation*: Any caller calling `upload_reel` or `get_creator_studio_data` is automatically provisioned as a verified creator (`is_verified = 1`) with no application submission, no terms acceptance, no review, and **no cap enforcement whatsoever**.

#### C. Reel Upload Implementation (`api/api.php:4776–4928`):
```php
$stmt = $pdo->prepare("INSERT INTO reels (creator_id, video_url, caption, music_title, phone_number, tags, views_count, likes_count, saves_count, comments_count, is_active) VALUES (?, ?, ?, ?, ?, ?, 0, 0, 0, 0, 1)");
```
*Direct Observation*:
- Does not capture `crop`, `category`, `language`, `source_url`, `content_hash`, `original_content_date`, or `rights_declared`.
- Does not validate against duplicate URLs or duplicate content hashes.
- Inserts directly with `is_active = 1` and without moderation status (`status = 'approved'` is bypassed; all reels go live immediately).

#### D. Farmer Privacy Exposure (`api/api.php:4430–4456` and `api/reels.php:99`):
```php
// In get_comments (api/reels.php:99):
SELECT id, reel_id, farmer_username, phone_number, user_id, comment_text, created_at FROM reel_comments WHERE reel_id = ?
// In getReels (api/api.php:4444):
'phoneNumber' => !empty($reel['phone_number']) ? $reel['phone_number'] : ($reel['creator_phone_number'] ?? ''),
```
*Direct Observation*: Raw 10-digit phone numbers and user identifiers of commenting/interacting farmers are sent unmasked over the public API.

---

## 2. Logic Chain

### Step 1: Absence of Program Schema Blocks End-to-End Capabilities
- **Premise**: Requirements R1, R2, and R3 specify a 25-creator pilot with structured onboarding, rights declaration, content review queue, tier-based payout calculations, campaign assignments, and audit logging.
- **Evidence**: 11 of the 13 required tables do not exist in either `u893187665_kiosk.sql` or `api/api.php` runtime migrations.
- **Inference**: Without auto-migrating these 11 tables (`creator_terms`, `creator_payment_profiles`, `reel_reviews`, `reel_events`, `monthly_creator_payouts`, `payout_line_items`, `campaigns`, `campaign_creator_assignments`, `campaign_deliverables`, `leads`, `audit_logs`) and altering `creators` and `reels`, neither the Flutter creator app nor the web admin dashboard can store or retrieve partner program state.

### Step 2: Auto-Provisioning Directly Conflicts with the 25-Creator Pilot Cap
- **Premise**: Requirement R3 states: *"Enforce maximum 25 active creators in the pilot at API level"*, and R2 requires an onboarding queue to approve/reject creators.
- **Evidence**: In `api/api.php` line 4758, `resolveOrCreateCreator()` inserts new records into `creators` with `is_verified = 1` unconditionally for every new phone number or username.
- **Inference**: The API currently lacks an onboarding application state machine (`applied` → `active`/`rejected`). To enforce the 25-creator cap, the backend must:
  1. Store incoming applications with `status = 'applied'`, `tier = 'trial'`, and `is_active = 0`.
  2. In the approval action handler (`action=admin_approve_creator`), execute `SELECT COUNT(*) FROM creators WHERE status = 'active'`. If the count is $\ge 25$, reject the approval with a 409 Conflict error.

### Step 3: Payout Engine Cannot Operate Without Strict Reel Review Status & Duplicate Check
- **Premise**: Acceptance criteria state: *"Only reels in approved status within the billing period count towards the base payout tier"* and *"Duplicate reel submissions (matching source URL or content hash) are blocked from receiving payout credit."*
- **Evidence**: Currently, `reels` table has no `status` column, no `source_url` column, and no `content_hash` column. Every uploaded reel is immediately visible (`is_active = 1`).
- **Inference**: The payout engine formula:
  $$\text{Approved Count} \to \text{Tier Payout}$$
  $$\begin{cases} 
  0-4: & ₹0 \\
  5-9: & ₹50 \\
  10-14: & ₹100 \\
  15-19: & ₹150 \\
  20-24: & ₹225 \\
  25-29: & ₹275 \\
  30+: & ₹300 
  \end{cases}$$
  requires counting:
  ```sql
  SELECT COUNT(id) FROM reels 
  WHERE creator_id = :creator_id 
    AND status = 'approved' 
    AND payout_eligible = 1
    AND DATE_FORMAT(COALESCE(reviewed_at, created_at), '%Y-%m') = :payout_month
  ```
  If duplicate detection flags a reel (`payout_eligible = 0`), it is automatically excluded from this count, maintaining payout integrity.

### Step 4: Separation of Base Uploads and Campaign Deliverables
- **Premise**: Requirement R2 and R3 state that campaign payouts must remain separate line items from monthly base upload payouts.
- **Evidence**: Campaigns and deliverables are currently non-existent.
- **Inference**: A parent table `monthly_creator_payouts` must record aggregated totals (`base_payout_amount`, `bonus_amount`, `campaign_amount`, `total_payout_amount`), while child table `payout_line_items` must record each individual credit:
  - `item_type = 'base_upload'` (linking to monthly tier calculation)
  - `item_type = 'bonus'` (manual admin discretionary bonuses)
  - `item_type = 'campaign'` (linking to `campaign_deliverables.id`)

### Step 5: Privacy by Design for Farmer Data
- **Premise**: Requirement R1 and R3 require analytics to strictly prevent exposure of unconsented farmer identities.
- **Evidence**: `reel_comments` and `reels` output raw phone numbers (`api/reels.php:99`, `api/api.php:4444`).
- **Inference**: All creator-facing and public APIs must pass farmer telephone numbers through a masking function (`maskPhoneNumber($phone) => 'XXXXXX' . substr($phone, -4)`), while analytics endpoints must only deliver aggregated sums (`total_views`, `total_likes`, `total_shares`, `qualified_inquiries_count`).

---

## 3. Caveats

1. **No Production Database Direct Connection**: We executed queries and syntax checks against the local codebase. The live MySQL database at `127.0.0.1:3306` (from `config.php`) was not queried directly via live socket, but `database/u893187665_kiosk.sql` was fully scanned to establish the baseline schema.
2. **Dual Endpoint Coexistence (`api/api.php` and `api/reels.php`)**: The Flutter app in `lib/services/creator_service.dart` has dual endpoints: `api.php` as primary and `reels.php` as secondary fallback. To guarantee zero regressions across mobile and web admin, the new tables and endpoints must be implemented inside `api/api.php`, and `reels.php` should either delegate to `api.php` or mirror the core schema migrations.
3. **Existing Flutter UI Assumptions**: The existing Flutter UI in `test/creator_studio_test.dart` and `creator_studio_screen.dart` expects certain keys (`totalViews`, `totalLikes`, `reels`, `articles`). All schema extensions must be backward-compatible so that existing tests pass while new partner program features are introduced.

---

## 4. Conclusion

The current backend is a basic, unmoderated short-video upload script that lacks all structural foundations of the **Agri Creator Partner Program**. 

To satisfy requirements R1, R2, and R3, the backend architecture in `api/api.php` must be upgraded with four core subsystems:

### 4.1 Schema Migration Subsystem (Auto-migrated via `api/api.php` bootstrap)
Implement idempotent `CREATE TABLE IF NOT EXISTS` and `ALTER TABLE ADD COLUMN` queries for:
1. `creators`: Add `status`, `tier`, `agriculture_niches`, `languages`, `social_handles`, `application_date`, `approved_at`, `rejected_at`, `rejection_reason`, `reviewed_by`.
2. `creator_terms`: Versioned agreement records (`terms_version`, `content_ownership_declared`, `rights_acceptance_declared`, `accepted_ip`, `accepted_at`).
3. `creator_payment_profiles`: Masked payment profile (`payment_mode`, `upi_id`, `bank_account_number`, `bank_ifsc`, `account_holder_name`, `is_verified`).
4. `reels`: Add `crop`, `category`, `language`, `source_url`, `content_hash`, `original_content_date`, `rights_declared`, `status`, `payout_eligible`, `rejection_reason_code`, `reviewer_feedback`, `reviewed_at`, `reviewed_by`.
5. `reel_reviews`: Moderation audit logs (`reel_id`, `reviewer_name`, `action`, `reason_code`, `notes`, `created_at`).
6. `reel_events`: Telemetry events (`reel_id`, `event_type`, `farmer_phone_masked`, `metadata`).
7. `monthly_creator_payouts`: Monthly ledger (`creator_id`, `payout_month`, `approved_reels_count`, `base_payout_amount`, `bonus_amount`, `campaign_amount`, `total_payout_amount`, `status`, `lock_batch_id`, `payment_reference`, `paid_at`).
8. `payout_line_items`: Itemized transactions (`payout_id`, `creator_id`, `item_type`, `reference_id`, `title`, `amount`).
9. `campaigns`: Brand campaigns (`title`, `brand_name`, `description`, `crop`, `target_region`, `total_budget`, `start_date`, `end_date`, `status`).
10. `campaign_creator_assignments`: Assignments (`campaign_id`, `creator_id`, `negotiated_fee`, `status`).
11. `campaign_deliverables`: Deliverables (`assignment_id`, `campaign_id`, `creator_id`, `deliverable_title`, `deadline`, `proof_url`, `status`, `payout_approved`, `payout_amount`).
12. `leads`: Creator reel attribution leads (`creator_id`, `reel_id`, `lead_type`, `crop_name`, `farmer_phone_masked`, `status`).
13. `audit_logs`: Immutable administrative audit logs (`admin_user`, `action`, `entity_type`, `entity_id`, `old_state`, `new_state`, `ip_address`).

### 4.2 Deterministic Payout Engine Specification
A dedicated helper function `calculateMonthlyPayout($pdo, $payoutMonth)` executing the exact tier ladder:
```php
function getTierBasePayout(int $approvedCount): float {
    if ($approvedCount >= 30) return 300.00;
    if ($approvedCount >= 25) return 275.00;
    if ($approvedCount >= 20) return 225.00;
    if ($approvedCount >= 15) return 150.00;
    if ($approvedCount >= 10) return 100.00;
    if ($approvedCount >= 5)  return 50.00;
    return 0.00;
}
```
Only reels matching `status = 'approved'`, `payout_eligible = 1`, and falling inside `$payoutMonth` increment `$approvedCount`.

### 4.3 25-Creator Pilot Cap & Security Guardrail Specification
- During creator approval:
```php
$stmtCount = $pdo->query("SELECT COUNT(*) FROM creators WHERE status = 'active'");
$activeCount = (int)$stmtCount->fetchColumn();
if ($activeCount >= 25) {
    echo json_encode(['success' => false, 'error' => 'Pilot capacity reached (maximum 25 active creators)']);
    return;
}
```
- During reel submission:
  - Calculate SHA256 of normalized `source_url` or uploaded file.
  - Query existing records for duplicate URL or hash. If found, mark `payout_eligible = 0` and flag for moderator review.

### 4.4 Privacy Masking Helper Specification
```php
function maskPhoneNumber(?string $phone): string {
    if (empty($phone)) return '';
    $clean = preg_replace('/[^0-9]/', '', $phone);
    if (strlen($clean) >= 4) {
        return str_repeat('X', strlen($clean) - 4) . substr($clean, -4);
    }
    return 'XXXX';
}
```

---

## 5. Verification Method

To independently verify all findings and validate future implementations, execute the following commands in order:

### 5.1 PHP Syntax and Linter Verification
Run directly in PowerShell from the project root:
```powershell
php -l api/api.php
php -l studio_dashboard.php
php -l api/reels.php
```
*Expected Result*: Output must read `No syntax errors detected in <filename>` with exit code 0.

### 5.2 Schema Idempotency Verification
Run a standalone migration verification script via CLI:
```powershell
php -r "require 'api/config.php'; require 'api/api.php';"
```
Verify that all 13 tables are created without throwing PDO exceptions or collation mismatch warnings.

### 5.3 Deterministic Payout Engine Unit Verification
Execute a verification script testing the 7 tier boundaries:
```powershell
php -r "
require 'api/api.php';
assert(getTierBasePayout(0) === 0.0);
assert(getTierBasePayout(4) === 0.0);
assert(getTierBasePayout(5) === 50.0);
assert(getTierBasePayout(9) === 50.0);
assert(getTierBasePayout(10) === 100.0);
assert(getTierBasePayout(14) === 100.0);
assert(getTierBasePayout(15) === 150.0);
assert(getTierBasePayout(19) === 150.0);
assert(getTierBasePayout(20) === 225.0);
assert(getTierBasePayout(24) === 225.0);
assert(getTierBasePayout(25) === 275.0);
assert(getTierBasePayout(29) === 275.0);
assert(getTierBasePayout(30) === 300.0);
assert(getTierBasePayout(45) === 300.0);
echo 'All payout tier assertions passed!' . PHP_EOL;
"
```

### 5.4 Flutter Test and Analysis Verification
Verify client integrity and compile status:
```powershell
flutter analyze
flutter test test/creator_studio_test.dart
```
*Expected Result*: 0 analysis issues and all tests passing.

---

### Invalidation Conditions
This survey report would be invalidated if:
1. Tables for `monthly_creator_payouts` or `creator_terms` exist under alternative table names in a separate database schema not linked to `api/config.php`.
2. Payout tiers are configured dynamically via an external admin portal database not surveyed in `u893187665_kiosk.sql`.
