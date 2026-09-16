# Dispatch: Explorer 2 (Web Admin Dashboard Survey)

## Task Description
Survey and investigate the web admin dashboard codebase (`studio_dashboard.php` and any associated assets/scripts) against the requirements in `c:\Users\reddy\Downloads\Projects\cropsync\.agents\ORIGINAL_REQUEST.md`.

## Working Directory
c:\Users\reddy\Downloads\Projects\cropsync\.agents\explorer_survey_2

## Instructions
1. Read `c:\Users\reddy\Downloads\Projects\cropsync\.agents\ORIGINAL_REQUEST.md`.
2. Inspect `studio_dashboard.php` and related frontend/backend components in `c:\Users\reddy\Downloads\Projects\cropsync`.
3. Document:
   - Existing dashboard views/tabs vs required views:
     - Creator Onboarding Queue (review applications, verify social links and niches, approve/reject, assign tiers, enforce 25-creator cap).
     - Content Review Queue (video preview, metadata display, duplicate URL warning, Approve, Request Changes, Reject with standardized reason codes: copyright, duplicate, misleading, low quality, policy violation).
     - Payout Centre (deterministic monthly payout calculator for selected calendar months, bonus line items, exception/holding, batch lock, finance approval, CSV/Excel export, mark-as-paid reconciliation with reference/date).
     - Campaign Management Hub (create brand campaigns, assign creators, track deliverables, proof URLs, approve payouts).
     - Analytics & Audit Log (platform KPI leaderboard, immutable audit log viewer).
   - Integration points with `api/api.php` or direct DB access.
   - UI structure, styling, JavaScript handlers, and modal dialogs.
4. Produce a detailed findings report and write it to `c:\Users\reddy\Downloads\Projects\cropsync\.agents\explorer_survey_2\handoff.md`.
5. Send a completion message back to orchestrator.
