# BRIEFING — 2026-09-15T16:35:00Z

## Mission
Revamp CropSync's content creator screens and partner program functionality across Flutter mobile app, PHP web admin dashboard, and MySQL API backend based on the Agri Creator Partner Program technical specification (25-creator pilot, tiered ₹0–₹300 monthly upload payouts, moderation workflows, campaign deliverables, and creator analytics).

## 🔒 My Identity
- Archetype: Project Orchestrator (Orchestrator 2)
- Roles: orchestrator, user_liaison, human_reporter, successor
- Working directory: c:\Users\reddy\Downloads\Projects\cropsync\.agents\orchestrator_2
- Original parent: Sentinel
- Original parent conversation ID: 85171153-ab4c-445a-b141-c27e075eac0c

## 🔒 My Workflow
- **Pattern**: Project Orchestrator (Dual Track: Implementation & E2E Verification)
- **Scope document**: c:\Users\reddy\Downloads\Projects\cropsync\PROJECT.md
1. **Decompose**:
   - M1: Backend Schema & Core API Logic (`api/api.php`) — 13 tables auto-migrated, deterministic ₹0–₹300 monthly payout engine, 25-creator cap, duplicate detection, privacy masking, immutable audit logging.
   - M2: Web Admin Management Dashboard (`studio_dashboard.php`) — 5 core tabs: Creator Onboarding Queue (25 cap), Content Review Queue (with reason codes), Payout Centre (deterministic calculator, batch lock, reconciliation), Campaign Hub, Analytics & Audit Log.
   - M3: Creator Mobile App Revamp (`lib/screens/creator/`, models, services) — Onboarding & Rights Acceptance, Dashboard (30-reel progress, ₹0–₹300 estimator, partner tier), Reel Upload (crop/category/source/rights), My Reels (6-state management & resubmission), Analytics & Payouts, Campaigns & Deliverables.
   - M4: E2E Integration, Verification & Test Suite (`test/creator_studio_test.dart`, `php -l api/api.php`, `php -l studio_dashboard.php`, `flutter analyze`, `flutter test`).
2. **Dispatch & Execute**:
   - Implementation Track: Sequential milestones M1 -> M2 -> M3 -> M4.
   - For each milestone: Explorer -> Worker -> Reviewer -> Challenger -> Auditor -> Gate check.
3. **On failure**:
   - Retry -> Replace -> Skip (non-critical) -> Redistribute -> Redesign. Auditor veto is absolute.
4. **Succession**:
   - At 16 spawns, write handoff.md, cancel crons, spawn successor.

## 🔒 Key Constraints
- Never write, modify, or create source code files directly (dispatch workers).
- Never run build/test commands yourself (dispatch workers/reviewers).
- Never investigate or explore at the code level directly.
- Binary veto on Forensic Auditor integrity violations.
- Always enforce maximum 25 active creators in pilot.
- Deterministic monthly payout ladder: 0-4: ₹0, 5-9: ₹50, 10-14: ₹100, 15-19: ₹150, 20-24: ₹225, 25-29: ₹275, 30+: ₹300.
- Strict farmer privacy: no unconsented farmer phone numbers/identities exposed in creator analytics.

## Current Parent
- Conversation ID: 85171153-ab4c-445a-b141-c27e075eac0c
- Updated: 2026-09-15T16:35:00Z

## Key Decisions Made
- Ingested Phase 0 survey handoffs from Explorer 1 (API & Schema), Explorer 2 Gen 2 (Admin Dashboard), and Explorer 3 Gen 2 (Flutter App & Tests).
- Decomposed revamp into 4 concrete milestones: M1 (Backend API & Schema), M2 (Web Admin Dashboard), M3 (Flutter Mobile App), M4 (E2E Test Verification & Hardening).
- Scheduled 10-minute heartbeat cron (task-28).

## Team Roster
| Agent | Type | Work Item | Status | Conv ID |
|---|---|---|---|---|
| explorer_survey_1 | teamwork_preview_explorer | Survey Backend & Schema | COMPLETED | predecessor |
| explorer_survey_2_gen2 | teamwork_preview_explorer | Survey Web Admin Dashboard | COMPLETED | predecessor |
| explorer_survey_3_gen2 | teamwork_preview_explorer | Survey Flutter App & Tests | COMPLETED | predecessor |

## Succession Status
- Succession required: no
- Spawn count: 0 / 16
- Pending subagents: none
- Predecessor: orchestrator_1
- Successor: not yet spawned

## Active Timers
- Heartbeat cron: 8008978a-960a-430d-b386-7c2ca2c0c166/task-28
- Safety timer: none

## Artifact Index
- `c:\Users\reddy\Downloads\Projects\cropsync\.agents\ORIGINAL_REQUEST.md` — Authoritative requirements
- `c:\Users\reddy\Downloads\Projects\cropsync\PROJECT.md` — Project architecture, milestones, interfaces
- `c:\Users\reddy\Downloads\Projects\cropsync\.agents\orchestrator_2\progress.md` — Orchestrator liveness & checklist
- `c:\Users\reddy\Downloads\Projects\cropsync\.agents\orchestrator_2\GATE_STATUS.md` — Milestone gate records
