# Project: CropSync Agri Creator Partner Program Revamp

## Architecture
CropSync Agri Creator Partner Program is a tri-platform system consisting of:
1. **Backend REST API & Database Schema (`api/api.php`)**:
   - MySQL database with 13 auto-migrated tables.
   - Deterministic monthly upload payout engine (₹0–₹300 tier ladder based on approved eligible reels).
   - Strict 25-creator pilot cap enforcement at application/approval level.
   - Duplicate reel detection (source URL and content hash).
   - Farmer privacy masking engine (`maskPhoneNumber`).
   - Immutable audit logging for administrative actions.
2. **Web Admin Dashboard (`studio_dashboard.php`)**:
   - Single-page responsive administration portal with Alpine.js and Phosphor icons.
   - 5 dedicated program tabs:
     - Creator Onboarding Queue (application review, tier assignment, 25-cap counter).
     - Content Review Queue (video player preview, metadata inspection, duplicate warning banner, Approve/Request Changes/Reject with 5 reason codes).
     - Payout Centre (calendar month selector, deterministic calculator, bonus allocator, hold toggle, batch lock, finance approval, CSV export, mark-as-paid reconciliation).
     - Campaign Management Hub (brand campaign creation, creator assignment with negotiated fee, deliverable proof URL verification, campaign payout approval).
     - Analytics & Audit Log (KPI leaderboard, platform metrics, immutable audit logs).
     - Preserves existing Krishi News and legacy comments management.
3. **Flutter Mobile Application (`lib/screens/creator/`, `lib/models/`, `lib/services/`)**:
   - Mobile client for content creators.
   - Onboarding & Terms/Rights Acceptance flow with validation and terms gating.
   - Creator Dashboard with 30-reel progress bar, real-time estimated payout (₹0–₹300), partner tier badge, and notification alerts.
   - Enhanced Reel Upload form (crop, category, language, source URL, original content date, rights declaration check, duplicate check).
   - 6-state My Reels management (`draft`, `submitted`, `under_review`, `changes_requested`, `approved`, `rejected`), rejection reason badges, reviewer feedback notes, in-place resubmission.
   - Creator Analytics & Monthly Payouts card (aggregated metrics without exposing farmer identities).
   - Brand Campaigns & Deliverables tracking with proof URL submission.

---

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---|---|---|---|
| F01 | 13-Table Auto-Migration | Auto-migrate `creators`, `creator_terms`, `creator_payment_profiles`, `reels`, `reel_reviews`, `reel_events`, `monthly_creator_payouts`, `payout_line_items`, `campaigns`, `campaign_creator_assignments`, `campaign_deliverables`, `leads`, `audit_logs` | M1 | R3 §31 |
| F02 | Deterministic Payout Engine | Monthly tier calculator (0-4: ₹0, 5-9: ₹50, 10-14: ₹100, 15-19: ₹150, 20-24: ₹225, 25-29: ₹275, 30+: ₹300) | M1 | R3 §32-39 |
| F03 | 25-Creator Pilot Cap | Enforce maximum 25 active creators at API level and onboarding approval | M1 | R3 §40 |
| F04 | Duplicate Reel Detection | Block duplicate source URLs and content hashes from receiving payout credit | M1 | R3 §40 |
| F05 | Privacy Guardrails | Strict phone number masking and aggregation to protect farmer identities | M1 | R3 §40 |
| F06 | Immutable Audit Logging | Record actor, action, entity, before/after states for admin decisions | M1 | R3 §40 |
| F07 | Admin Creator Onboarding Queue | Review creator applications, verify niches/socials/UPI, assign tier, enforce 25 cap | M2 | R2 §23 |
| F08 | Admin Content Review Queue | Moderation queue with video preview, metadata, duplicate warning, 5 reason codes | M2 | R2 §24 |
| F09 | Admin Payout Centre | Deterministic calculator, bonus lines, hold manager, batch lock, finance approval, CSV export, mark-as-paid reconciliation | M2 | R2 §25 |
| F10 | Admin Campaign Hub | Create campaigns, assign creators with fees, review deliverable proof URLs, approve campaign payouts | M2 | R2 §26 |
| F11 | Admin Analytics & Audit Log | Platform KPI leaderboard and immutable audit log table viewer | M2 | R2 §27 |
| F12 | Creator Onboarding & Rights Screen | Multi-step form for profile, niches, languages, socials, UPI, terms & rights acceptance | M3 | R1 §14 |
| F13 | Mobile Creator Dashboard | 30-reel progress tracker, ₹0-₹300 payout estimate, approved counter, tier badge, alerts | M3 | R1 §15 |
| F14 | Enhanced Reel Submission | Crop, category, language, source URL, date, rights check, duplicate pre-check | M3 | R1 §16 |
| F15 | 6-State Reels Management | Filterable list, status badges, rejection codes, reviewer notes, in-place resubmit | M3 | R1 §17 |
| F16 | Creator Analytics & Payouts Card | Monthly payout tier summary, bonus line items, payment status, privacy-safe analytics | M3 | R1 §18 |
| F17 | Mobile Campaigns & Deliverables | View assigned brand campaigns, deadlines, negotiated fee, proof URL submission | M3 | R1 §19 |
| F18 | Test Suite & E2E Verification | Fix failing tests in `test/creator_studio_test.dart`, expand unit tests, verify `php -l`, `flutter analyze`, and `flutter test` | M4 | AC §45-64 |

---

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|---|---|---|---|
| M1 | Backend Schema & Core API Logic | Auto-migrations for 13 tables, deterministic monthly payout engine, 25-creator cap, duplicate detection, privacy masking, immutable audit logging in `api/api.php` | None | PLANNED |
| M2 | Web Admin Management Dashboard | 5 tabs in `studio_dashboard.php`: Onboarding Queue (25 cap), Moderation Queue, Payout Centre, Campaign Hub, Analytics & Audit Log | M1 | PLANNED |
| M3 | Creator Mobile Application Revamp | Flutter screens in `lib/screens/creator/`, models in `lib/models/`, services in `lib/services/` | M1 | PLANNED |
| M4 | E2E Integration & Test Suite Hardening | Fix existing test failures in `test/creator_studio_test.dart`, add comprehensive unit/widget tests, verify `flutter analyze`, `flutter test`, `php -l` | M1, M2, M3 | PLANNED |

---

## Interface Contracts

### 1. Backend REST API Endpoints (`api/api.php`)
- `action=get_creator_profile`:
  - Request: `GET ?action=get_creator_profile&creator_id=X` (or phone_number / user_id)
  - Response: `{ "success": true, "creator": { "id": 1, "username": "...", "display_name": "...", "status": "active", "partnership_tier": "trial", "niches": [...], "languages": [...], "social_handles": {...}, "terms_accepted": true } }`
- `action=creator_onboard`:
  - Request: `POST` with `display_name`, `phone_number`, `email`, `bio`, `niches`, `languages`, `social_handles`, `upi_id`, `accept_terms: 1`, `accept_rights: 1`
  - Logic: Inserts into `creators` (`status = 'pending'`), `creator_terms`, `creator_payment_profiles`.
  - Response: `{ "success": true, "creator_id": 1, "status": "pending", "message": "Application submitted for review" }`
- `action=admin_approve_creator`:
  - Request: `POST` with `creator_id`, `tier` (`trial`, `active_partner`, `verified`, `strategic`), `action`: `approve` | `reject`, `reason`
  - Guardrail: If `action == 'approve'`, verify `SELECT COUNT(*) FROM creators WHERE status = 'active'` < 25. If >= 25, return 409 Conflict.
- `action=upload_reel`:
  - Request: `POST` with video file, `caption`, `crop`, `category`, `language`, `source_url`, `original_content_date`, `rights_confirmed: 1`
  - Validation: Check terms acceptance; compute SHA256 of `source_url`/content; check duplicates. If duplicate, flag `is_duplicate = 1` and `payout_eligible = 0`. Status set to `submitted`.
- `action=calculate_monthly_payout`:
  - Request: `POST/GET` with `billing_month` (YYYY-MM)
  - Calculation: Count approved, non-duplicate reels for creator in billing month.
    - 0-4: ₹0.00
    - 5-9: ₹50.00
    - 10-14: ₹100.00
    - 15-19: ₹150.00
    - 20-24: ₹225.00
    - 25-29: ₹275.00
    - 30+: ₹300.00
  - Sum approved bonus line items and campaign deliverables.
- `action=lock_payout_batch` & `action=mark_payout_paid`:
  - Transition states: `calculated` -> `locked` -> `approved` -> `paid` (with UTR reference). Immutable audit log entry written.

### 2. Moderation Reason Codes
- `copyright`: Unauthorized third-party audio/video without license.
- `duplicate`: Re-upload of existing source URL or identical video hash.
- `misleading`: Inaccurate agricultural advice or fraudulent claims.
- `low_quality`: Poor video/audio quality or corrupted file.
- `policy_violation`: Explicit, abusive, or non-agricultural promotional content.

---

## Code Layout & Write Boundaries
- Milestone 1 exclusively modifies: `api/api.php` (and optionally test scripts).
- Milestone 2 exclusively modifies: `studio_dashboard.php`.
- Milestone 3 exclusively modifies: `lib/screens/creator/`, `lib/models/`, `lib/services/`.
- Milestone 4 exclusively modifies: `test/creator_studio_test.dart` and runs holistic verifications across all components.
- Agent metadata files are strictly restricted to `.agents/<agent_dir>/`.
