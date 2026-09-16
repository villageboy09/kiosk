# Original User Request

## 2026-09-15T15:30:47Z

Revamp CropSync's content creator screens and end-to-end partner program functionality across the Flutter mobile app, PHP web admin dashboard, and MySQL API backend based on the Agri Creator Partner Program technical specification (25-creator pilot, tiered ₹0–₹300 monthly upload payouts, moderation workflows, campaign deliverables, and creator analytics).

Working directory: c:/Users/reddy/Downloads/Projects/cropsync
Integrity mode: development

## Requirements

### R1. Creator Mobile Application Revamp (Flutter)
Revamp the Creator screens (`lib/screens/creator/` and associated models/services) to implement the specification:
- **Onboarding & Rights Acceptance**: Structured onboarding flow capturing display name, bio, phone, email, agriculture niches, languages, social handles, masked payment/UPI profile, and explicit checkbox acceptance of program terms and content ownership/rights declarations.
- **Creator Dashboard**: Current monthly progress tracker towards the 30-reel target, real-time estimated earned base payout (₹0 to ₹300), approved reel counter, program status badge (Trial, Active Partner, Verified, Strategic), and urgent notification alerts.
- **Agri Reels Submission**: Video upload/import form requiring crop, category, language, caption, source attribution URL, original content date, and rights declaration check, with validation against duplicate submissions.
- **My Reels Management & Status**: Filterable reels list with live status indicators (`draft`, `submitted`, `under_review`, `changes_requested`, `approved`, `rejected`), rejection reason badges, reviewer feedback notes, and in-place resubmission.
- **Creator Analytics & Payouts**: Monthly payout summary showing base payout tier, approved bonus line items, payment status, and aggregated engagement insights (views, likes, shares, saves, qualified inquiries) while strictly preventing exposure of private farmer identities.
- **Campaigns & Deliverables**: Tab/screen showing assigned sponsored campaigns, commercial deliverables, deadlines, negotiated fee, and proof URL submission controls.

### R2. Web Admin Management Dashboard (`studio_dashboard.php`)
Revamp and modernize the admin web dashboard to provide complete administrative oversight:
- **Creator Onboarding Queue**: Review creator applications, verify social links and niches, approve/reject creators, assign partnership tiers, and enforce the 25-creator pilot cap.
- **Content Review Queue**: Interactive moderation queue with video preview, metadata display, duplicate source URL warning, and moderation action buttons (Approve, Request Changes, Reject with standardized reason codes: copyright, duplicate, misleading, low quality, policy violation).
- **Payout Centre**: Deterministic monthly payout calculator for selected calendar months, bonus line item allocator, exception/holding manager, batch lock, finance approval workflow, CSV/Excel export, and mark-as-paid reconciliation recording payment reference and date.
- **Campaign Management Hub**: Create brand campaigns, assign creators, track deliverable proof URLs, review deliverables, and approve campaign-specific payouts separate from base upload payouts.
- **Analytics & Audit Log**: Platform KPI leaderboard (active creators, submissions, approval rate, total payout spend) and immutable audit log viewer tracking all administrative actions.

### R3. Backend Schema & API Business Logic (`api/api.php`)
Extend MySQL database schema and REST API endpoints to support the program:
- **Database Schema**: Implement and auto-migrate tables for `creators`, `creator_terms`, `creator_payment_profiles`, `reels`, `reel_reviews`, `reel_events`, `monthly_creator_payouts`, `payout_line_items`, `campaigns`, `campaign_creator_assignments`, `campaign_deliverables`, `leads`, and `audit_logs`.
- **Deterministic Monthly Payout Engine**: Implement monthly calculation logic applying tier rules strictly based on approved eligible reels:
  - 0–4 approved reels: ₹0
  - 5–9 approved reels: ₹50
  - 10–14 approved reels: ₹100
  - 15–19 approved reels: ₹150
  - 20–24 approved reels: ₹225
  - 25–29 approved reels: ₹275
  - 30+ approved reels: ₹300 (maximum base payout)
- **Program Guardrails & Security**: Enforce maximum 25 active creators in the pilot at API level, prevent duplicate URL uploads from counting towards payouts, record immutable audit log entries for all approval/payout actions, and ensure creator-scoped analytics never expose unconsented farmer data.

## Acceptance Criteria

### Creator Experience (Flutter)
- [ ] Creator cannot submit reels without accepted terms and rights declaration records.
- [ ] Reel submission captures required metadata (crop, category, language, source URL, rights confirmation).
- [ ] Creator dashboard displays live monthly approved count, calculated tier payout estimate, and current partnership tier.
- [ ] Reels with `changes_requested` or `rejected` display reviewer comments and allow editing and resubmitting.
- [ ] Flutter app and creator screens compile and pass tests (`flutter analyze` and `flutter test test/creator_studio_test.dart`).

### Moderation & Admin Operations (PHP Web Admin)
- [ ] Admin can approve or reject creator onboarding, with the 25-creator pilot cap strictly enforced.
- [ ] Content queue provides video preview, metadata inspection, and approve/reject/request changes actions with reason codes.
- [ ] Moderation history and decisions remain immutable in `reel_reviews` and `audit_logs`.
- [ ] Admin can create campaigns, assign creators with negotiated fees, and approve submitted proof deliverables.

### Payout Engine & Data Integrity (API & Database)
- [ ] Payout engine produces deterministic, reproducible results for any calendar month matching the exact specification tier table.
- [ ] Only reels in `approved` status within the billing period count towards the base payout tier.
- [ ] Duplicate reel submissions (matching source URL or content hash) are blocked from receiving payout credit.
- [ ] Finance admin can lock a payout batch, approve it, export CSV, and record payment references.
- [ ] Campaign payouts remain separate line items from monthly upload base payouts.
- [ ] All API scripts pass PHP syntax checks (`php -l api/api.php` and `php -l studio_dashboard.php`).
