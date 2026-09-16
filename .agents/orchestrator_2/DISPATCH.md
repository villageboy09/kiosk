# Dispatch Task Assignment

## 2026-09-15T16:28:35Z

You are the Project Orchestrator (Orchestrator 2) for CropSync's content creator screens and partner program revamp.

## Workspace & Working Directory
- Workspace Root: c:\Users\reddy\Downloads\Projects\cropsync
- Your Working Directory: c:\Users\reddy\Downloads\Projects\cropsync\.agents\orchestrator_2
- Authoritative User Request: c:\Users\reddy\Downloads\Projects\cropsync\.agents\ORIGINAL_REQUEST.md

## Predecessor Context & Completed Hand-offs
Your predecessor initiated the Phase 0 Survey. Two comprehensive hand-offs are already completed and available for you to ingest immediately:
1. Explorer 1 (Backend API & Database Schema): `c:\Users\reddy\Downloads\Projects\cropsync\.agents\explorer_survey_1\handoff.md` (detailed audit of api/api.php, schema migrations, missing tables, deterministic payout engine, 25-creator cap, and guardrails).
2. Explorer 2 (Admin Web Dashboard): `c:\Users\reddy\Downloads\Projects\cropsync\.agents\explorer_survey_2_gen2\handoff.md` (detailed audit of studio_dashboard.php, onboarding queues, moderation workflows, payout reconciliation, campaigns, and audit logs).
3. Explorer 3 (Flutter Mobile App): check `c:\Users\reddy\Downloads\Projects\cropsync\.agents\explorer_survey_3_gen2/` for existing progress and finish or inspect Flutter creator screens (`lib/screens/creator/`) and `test/creator_studio_test.dart`.

## Mission & Requirements
Revamp CropSync's content creator screens and partner program functionality across Flutter mobile app, PHP web admin dashboard, and MySQL API backend:
- R1: Creator Mobile Application Revamp (Flutter) — Onboarding & Rights, Creator Dashboard, Reels Submission, Reels Management, Analytics & Payouts, Campaigns & Deliverables.
- R2: Web Admin Management Dashboard (studio_dashboard.php) — Creator Onboarding Queue (25-creator cap), Content Review Queue, Payout Centre (deterministic calculator, batch lock, reconciliation), Campaign Management Hub, Analytics & Audit Log.
- R3: Backend Schema & API Logic (api/api.php) — 13 tables auto-migrated, deterministic monthly payout engine (₹0-₹300 tiers), 25-creator cap, duplicate detection, immutable audit logs, privacy guardrails.

## Acceptance Criteria
- php -l api/api.php and php -l studio_dashboard.php pass.
- flutter analyze and flutter test test/creator_studio_test.dart compile and pass.
- All user acceptance criteria in ORIGINAL_REQUEST.md verified.

## Protocol
- Maintain your BRIEFING.md and progress.md in `c:\Users\reddy\Downloads\Projects\cropsync\.agents\orchestrator_2`. Update progress.md frequently.
- Synthesize the architecture into PROJECT.md and coordinate execution with subagents.
- Report completion via send_message to parent sentinel when all work is finished and verified.
