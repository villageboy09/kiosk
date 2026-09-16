# Handoff Report: Flutter Mobile App & Tests Survey (Explorer 3 Gen 2)

**Explorer**: Explorer 3 Gen 2 (Flutter Mobile App & Tests Explorer)  
**Date**: 2026-09-15  
**Working Directory**: `c:\Users\reddy\Downloads\Projects\cropsync\.agents\explorer_survey_3_gen2`  
**Status**: Completed Survey & Synthesis  

---

## 1. Observation

### 1.1 Codebase & Dependency Baseline
- **Flutter & Dart SDK**: `pubspec.yaml` lines 8–10 specifies SDK `>=3.4.3 <4.0.0`, version `1.0.14+60`.
- **Key Dependencies** (`pubspec.yaml` lines 11–45):
  - HTTP networking: `http: ^1.5.0`
  - Video & Media: `video_player: ^2.10.0`, `chewie: ^1.13.0`, `image_picker: ^1.2.3`
  - Data Visualization: `fl_chart: ^1.2.0`
  - Localization: `easy_localization: ^3.0.8` (uses `.tr()` translations and JSON asset loaders)
  - Persistence & State: `shared_preferences: ^2.2.2`. The app does not use BLoC or Riverpod; it utilizes native Flutter `StatefulWidget` / `setState`, `ValueNotifier`, and `ChangeNotifier` (e.g. `CreatorHomeScreen.tabNotifier`).
  - Base API endpoint: `ApiService.baseUrl = 'https://kiosk.cropsync.in/api'` (`lib/services/api_service.dart:13`).

### 1.2 Static Analysis Command & Results
- **Command Executed**: `flutter analyze`
- **Verbatim Result**:
  ```
  Analyzing cropsync...
  No issues found! (ran in 81.1s)
  ```
  The Flutter mobile app currently compiles cleanly with zero static analyzer lints or type errors.

### 1.3 Test Suite Execution & Verbatim Failures
- **Command Executed**: `flutter test test/creator_studio_test.dart`
- **Result**: 3 passed, 3 failed (exit code 1).
- **Exact Failure 1: Offline Fallback in Service**
  - Location: `test/creator_studio_test.dart:208:7`
  - Test: `CreatorService returns fallback data when offline`
  - Verbatim Output:
    ```
    Expected: <true>
      Actual: <false>
    test\creator_studio_test.dart 208:7  main.<fn>.<fn>
    ```
  - Root Cause Observation: In `lib/services/creator_service.dart` lines 595 and 608:
    ```dart
    stats: const CreatorStats(
      totalViews: 0, // 0 > 0 evaluates to false
      ...
    ),
    reels: [],
    articles: [],
    dailyTrends: [], // dailyTrends.isNotEmpty evaluates to false
    ```
    The fallback mock values returned in `_getDefaultStudioData` have zero views and empty trends, directly violating the test expectation `expect(studioData.stats.totalViews > 0, true)`.

- **Exact Failure 2: UploadReelScreen Header Text Mismatch**
  - Location: `test/creator_studio_test.dart:239:7`
  - Test: `UploadReelScreen renders form fields and suggested tag chips`
  - Verbatim Output:
    ```
    Expected: exactly one matching candidate
      Actual: _TextWidgetFinder:<Found 0 widgets with text "New Agri Reel": []>
       Which: means none were found but one was expected
    ```
  - Root Cause Observation: `test/creator_studio_test.dart:44` defines `'upload_reel_title': 'New Agri Reel'`, expecting the screen to use `'upload_reel_title'.tr()`. However, `lib/screens/creator/upload_reel_screen.dart` line 246 hardcodes:
    ```dart
    Text('REELS STUDIO', style: ...)
    ```
    Additionally, the test expects `'Publish Reel'` twice (`test/creator_studio_test.dart:243`), but line 278 has `'Publish'` and line 799 has `'Publish Reel Now'`.

- **Exact Failure 3: UploadNewsScreen Header Text Mismatch**
  - Location: `test/creator_studio_test.dart:260:7`
  - Test: `UploadNewsScreen renders category chips and form inputs`
  - Verbatim Output:
    ```
    Expected: exactly one matching candidate
      Actual: _TextWidgetFinder:<Found 0 widgets with text "Publish Agri Article": []>
       Which: means none were found but one was expected
    ```
  - Root Cause Observation: `test/creator_studio_test.dart:55` defines `'upload_news_title': 'Publish Agri Article'`. But `lib/screens/creator/upload_news_screen.dart` line 204 hardcodes:
    ```dart
    Text('NEWS EDITOR', style: ...)
    ```
    And line 237 has `'Publish'` instead of `'Publish Article'`.

### 1.4 Survey of Existing Screens & Architecture

#### A. Shell Navigation (`lib/screens/creator/creator_home_screen.dart`)
- Hosts 4 bottom navigation tabs:
  - Tab 0: `CreatorStudioScreen`
  - Tab 1: `ReelsScreen` (Public reels feed)
  - Tab 2: `NewsFeedScreen` (Public news feed)
  - Tab 3: `ProfileScreen` (User profile)
- Center action button opens modal bottom sheet with "Upload Reel" (`UploadReelScreen`) and "Upload News" (`UploadNewsScreen`).
- Displays a static AppBar badge: `'CREATOR'` (lines 310–331). No tier indicator (`Trial`, `Active Partner`, `Verified`, `Strategic`).

#### B. Creator Studio (`lib/screens/creator/creator_studio_screen.dart`)
- Has 3 tabs: My Reels, My Articles, Analytics.
- My Reels tab (`_buildReelsTab`, lines 287–350) renders reels with only an active/inactive toggle (`_toggleReelActive`) and delete button (`_deleteReel`).
- Analytics tab (`_buildAnalyticsTab`, lines 623–648) displays KPI cards (Total Views, Likes, Comments, Inquiries/Calls) and a weekly BarChart (`fl_chart`).
- Auto-refreshes every 10 seconds via `Timer.periodic`.

#### C. Reel Upload Screen (`lib/screens/creator/upload_reel_screen.dart`)
- Video picker (gallery/camera via `image_picker`), video preview player (`video_player`), caption input (500 chars), contact phone number input, and hashtag filter chips (`#PaddyCare`, `#DroneSpray`, etc.).

#### D. Creator Models & Services
- `lib/models/creator_studio_model.dart`: Contains `CreatorStats` (totals and rates), `DailyTrendItem`, and `CreatorStudioData`.
- `lib/models/reel_model.dart`: Contains `ReelCreator`, `ReelComment`, and `Reel`.
- `lib/services/creator_service.dart`: Handles HTTP endpoints:
  - `getStudioData`: `api.php?action=get_creator_studio_data`
  - `uploadReelDetailed` / `uploadReel`: `api.php?action=upload_reel`
  - `deleteReel`: `api.php?action=delete_reel`
  - `toggleReelStatus`: `api.php?action=toggle_reel_status`
  - `createNewsArticleDetailed` / `createNewsArticle`: `api.php?action=create_news_article`
  - `deleteNewsArticle`: `api.php?action=delete_news_article`
  - `toggleNewsStatus`: `api.php?action=toggle_news_status`

---

## 2. Logic Chain & Gap Analysis

From the direct observations in Section 1 and the specifications in `ORIGINAL_REQUEST.md` (R1, R3, Acceptance Criteria), the following gap analysis is established:

| Requirement Area (R1) | Existing Codebase State | Missing / Required Capabilities | Severity / Gap |
|---|---|---|---|
| **1. Onboarding & Rights Acceptance** | Completely missing. No onboarding screen exists in `lib/screens/creator/` or routes. `upload_reel_screen.dart` has no terms acceptance guardrail. | • Multi-step / structured onboarding flow capturing: display name, bio, phone, email, agriculture niches (chips), languages (chips), social handles (YouTube, Instagram, Facebook), and masked UPI profile.<br>• Explicit checkbox accepting program terms and content rights declaration.<br>• Guardrail: Block reel submission until terms and rights declaration records are accepted. | **Critical (0% present)** |
| **2. Creator Dashboard** | `creator_studio_screen.dart` has generic KPI counters (views, likes, comments, calls). | • Monthly progress tracker towards 30-reel target (e.g., `X/30` approved reels).<br>• Real-time estimated earned base payout (₹0–₹300) applying deterministic tier rules strictly based on approved reels.<br>• Approved reel counter for current calendar month.<br>• Program status badge (`Trial`, `Active Partner`, `Verified`, `Strategic`).<br>• Urgent notification alerts card (changes requested, batch locks, campaign notices). | **High (25% present)** |
| **3. Agri Reels Submission** | `upload_reel_screen.dart` captures video, caption, phone, hashtags. | • Crop selector (Paddy, Cotton, Chilli, etc.).<br>• Category selector.<br>• Content language selector.<br>• Source attribution URL input.<br>• Original content date picker.<br>• Mandatory rights declaration check box.<br>• Duplicate submission validation (preventing duplicate URL/hash). | **High (35% present)** |
| **4. My Reels Management & Status** | `creator_studio_screen.dart` displays list with active/inactive boolean switch and delete. | • 6-state status indicators: `draft`, `submitted`, `under_review`, `changes_requested`, `approved`, `rejected`.<br>• Filter chips by status.<br>• Rejection reason badges (`copyright`, `duplicate`, `misleading`, `low_quality`, `policy_violation`).<br>• Reviewer feedback notes display card.<br>• In-place resubmission flow for `changes_requested` / `rejected` reels. | **Critical (20% present)** |
| **5. Creator Analytics & Payouts** | `creator_studio_screen.dart` analytics tab shows generic views and watch time. Exposes farmer phone numbers in `ReelComment`. | • Monthly payout summary card showing: calendar month, base payout tier, approved bonus line items, total payout, and payment status (`pending`, `locked`, `approved`, `paid`).<br>• Aggregated engagement insights (views, likes, shares, saves, qualified inquiries).<br>• **Privacy Guardrail**: Creator analytics must strictly omit farmer names and phone numbers. | **High (20% present)** |
| **6. Campaigns & Deliverables** | Completely missing. No models, screens, or endpoints exist. | • Sponsored campaigns tab/screen showing: assigned campaigns, deliverables, deadlines, negotiated fee.<br>• Proof URL submission input and status tracker (`pending`, `submitted`, `approved`). | **Critical (0% present)** |

---

## 3. Detailed Architectural Recommendations for Implementation

### 3.1 Data Model Extensions (`lib/models/creator_studio_model.dart`)
1. **`CreatorProfile`**:
   - Fields: `int id`, `String userId`, `String displayName`, `String bio`, `String phone`, `String email`, `List<String> niches`, `List<String> languages`, `Map<String, String> socialHandles`, `String upiId`, `String maskedUpi`, `String partnerTier` (`Trial`, `Active Partner`, `Verified`, `Strategic`), `bool hasAcceptedTerms`, `DateTime? termsAcceptedAt`, `String status`.
2. **`ReelModel` (Enhanced)**:
   - Extend `lib/models/reel_model.dart` with: `String status` (`draft`, `submitted`, `under_review`, `changes_requested`, `approved`, `rejected`), `String crop`, `String category`, `String language`, `String sourceUrl`, `DateTime? originalContentDate`, `bool rightsAccepted`, `String? rejectionReason`, `String? reviewerNotes`, `DateTime? moderatedAt`, `bool isPayoutEligible`.
3. **`MonthlyPayoutSummary` & `PayoutLineItem`**:
   - `MonthlyPayoutSummary`: `String month` (YYYY-MM), `int approvedReelsCount`, `int basePayoutTierAmount`, `List<PayoutLineItem> bonusLineItems`, `int totalEarned`, `String payoutStatus` (`pending`, `locked`, `finance_approved`, `paid`, `held`), `String? paymentReference`, `DateTime? paidAt`.
   - `PayoutLineItem`: `int id`, `String title`, `int amount`, `String type` (`bonus`, `campaign`), `String notes`.
4. **`CreatorCampaign` & `CampaignDeliverable`**:
   - `CreatorCampaign`: `int id`, `String title`, `String brandName`, `String description`, `DateTime deadline`, `int negotiatedFee`, `String status`, `List<CampaignDeliverable> deliverables`.
   - `CampaignDeliverable`: `int id`, `int campaignId`, `String title`, `String requirements`, `String? proofUrl`, `String status` (`pending`, `submitted`, `approved`, `rejected`), `String? feedbackNotes`.

### 3.2 Service Layer Extensions (`lib/services/creator_service.dart`)
- **Deterministic Monthly Payout Tier Calculator**:
  ```dart
  static int calculateBasePayout(int approvedReelsCount) {
    if (approvedReelsCount >= 30) return 300;
    if (approvedReelsCount >= 25) return 275;
    if (approvedReelsCount >= 20) return 225;
    if (approvedReelsCount >= 15) return 150;
    if (approvedReelsCount >= 10) return 100;
    if (approvedReelsCount >= 5) return 50;
    return 0;
  }
  ```
- **New API Methods in `CreatorService`**:
  - `getCreatorProfile()`: calls `api.php?action=get_creator_profile`
  - `saveCreatorOnboarding(...)`: calls `api.php?action=creator_onboard`
  - `acceptProgramTerms(...)`: calls `api.php?action=accept_terms`
  - `getPayoutSummary({String? month})`: calls `api.php?action=get_monthly_payout`
  - `getAssignedCampaigns()`: calls `api.php?action=get_creator_campaigns`
  - `submitDeliverableProof(int deliverableId, String proofUrl)`: calls `api.php?action=submit_deliverable_proof`
  - `resubmitReel(...)`: calls `api.php?action=resubmit_reel`
  - `validateDuplicateReel(String sourceUrl)`: calls `api.php?action=check_duplicate_reel`

### 3.3 Screen Revamp & Organization Plan
1. **New Screen: `lib/screens/creator/creator_onboarding_screen.dart`**:
   - Clean multi-step or card-based flow with inputs for Name, Bio, Niches, Languages, Socials, Masked UPI, Terms Modal & Checkbox.
2. **Revamped `lib/screens/creator/creator_studio_screen.dart`**:
   - Convert to 4 structured tabs:
     - **Tab 1: Dashboard**: 30-reel monthly target progress bar, real-time estimated payout (₹0–₹300), approved reel count, partner tier badge, urgent alert cards.
     - **Tab 2: My Reels**: Status filters (`All`, `Under Review`, `Changes Requested`, `Approved`, `Rejected`), live status chips, rejection reason badges, reviewer feedback card, in-place edit/resubmit button.
     - **Tab 3: Analytics & Payouts**: Monthly payout summary card, tier breakdown, bonus items list, payment reference, and strictly aggregated privacy-safe engagement metrics.
     - **Tab 4: Campaigns**: List of assigned brand campaigns, deliverable checklists, deadlines, fee, and proof URL submission sheet.
3. **Revamped `lib/screens/creator/upload_reel_screen.dart`**:
   - Add crop picker, category dropdown, language dropdown, source attribution URL, original content date picker, rights declaration checkbox, and duplicate submission pre-check.
   - Align strings with test expectations (`'upload_reel_title'.tr()` = "New Agri Reel", `'upload_reel_publish_btn'.tr()` = "Publish Reel").
4. **Fix `UploadNewsScreen`**:
   - Align strings with test expectations (`'upload_news_title'.tr()` = "Publish Agri Article", `'upload_news_publish_btn'.tr()` = "Publish Article").

### 3.4 Test Suite Fixes & Expansion (`test/creator_studio_test.dart`)
1. Fix `CreatorService._getDefaultStudioData` to return non-zero `totalViews` (e.g. 1500) and at least one item in `dailyTrends`.
2. Ensure `UploadReelScreen` and `UploadNewsScreen` display localized titles and buttons matching `CreatorTestAssetLoader`.
3. Add dedicated unit tests for:
   - Deterministic base payout tier calculator (all brackets: 0–4 -> ₹0, 5–9 -> ₹50, 10–14 -> ₹100, 15–19 -> ₹150, 20–24 -> ₹225, 25–29 -> ₹275, 30+ -> ₹300).
   - Onboarding validation (empty name, invalid UPI, unchecked terms).
   - Reel submission form validation (missing crop, unaccepted rights declaration).
   - My Reels status filtering and rejection badge rendering.
   - Campaign deliverable submission and proof URL validation.
   - Privacy verification: ensure no farmer phone numbers or personal handles are returned in creator analytics.

---

## 4. Caveats

1. **Backend Integration**: This investigation was conducted in read-only mode on the mobile frontend codebase. Real network calls to `kiosk.cropsync.in` are mocked in unit tests (`TestWidgetsFlutterBinding` returns 400 for unmocked HTTP). Any new network calls must gracefully handle offline fallback modes.
2. **Pilot Cap (25 Creators)**: The pilot cap is primarily enforced at the API / backend level, but the Flutter onboarding flow should display an informative alert if registration returns a `pilot_cap_reached` error.
3. **Video Uploading in Tests**: In widget test environments, actual camera/video picking and `VideoPlayerController.file` playback cannot execute against real hardware decoders; tests should verify form controls and validation logic using mock controllers or simulated state.

---

## 5. Conclusion

The Flutter mobile application has a solid architectural base (`CreatorHomeScreen`, `CreatorStudioScreen`, `UploadReelScreen`, `UploadNewsScreen`, `CreatorService`) and passes `flutter analyze` with zero issues. However:
1. **Critical Feature Gaps**: All core requirements from `ORIGINAL_REQUEST.md` R1—including Onboarding & Rights Acceptance, 30-reel progress tracker, ₹0–₹300 tier payout calculator, 6-state reels review workflow, rejection reason badges, reviewer comments, in-place resubmissions, payout summary line items, and campaign deliverable submissions—are completely unbuilt or only minimally scaffolded.
2. **Current Test Failures**: `test/creator_studio_test.dart` has 3 failing tests stemming from hardcoded strings in the UI and zeroed fallback metrics in `CreatorService`.
3. **Clear Path to Compliance**: By fixing the 3 test mismatches, updating `CreatorService` and `CreatorStudioData` models, revamping `UploadReelScreen` with required metadata/rights checks, adding `CreatorOnboardingScreen`, and upgrading `CreatorStudioScreen` to support the 6-state workflow, payout calculator, and campaigns, the Flutter app will fully satisfy all R1 requirements and pass `flutter analyze` and `flutter test test/creator_studio_test.dart`.

---

## 6. Verification Method

To independently verify the findings in this report:

1. **Verify Static Analyzer**:
   ```powershell
   flutter analyze
   ```
   *Expected Output*: "No issues found!"

2. **Verify Existing Test Failures in `test/creator_studio_test.dart`**:
   ```powershell
   flutter test test/creator_studio_test.dart
   ```
   *Expected Output*: 3 test failures matching Section 1.3:
   - `CreatorService returns fallback data when offline` (line 208)
   - `UploadReelScreen renders form fields and suggested tag chips` (line 239: looking for "New Agri Reel")
   - `UploadNewsScreen renders category chips and form inputs` (line 260: looking for "Publish Agri Article")

3. **Verify Code Locations**:
   - Fallback data: Inspect `lib/services/creator_service.dart:584–610` (`_getDefaultStudioData`).
   - Hardcoded AppBar titles: Inspect `lib/screens/creator/upload_reel_screen.dart:246` ("REELS STUDIO") and `lib/screens/creator/upload_news_screen.dart:204` ("NEWS EDITOR").
   - Absence of Onboarding and Campaign screens: Inspect `lib/screens/creator/` directory (`list_dir` / `find_by_name`).
   - Absence of status workflow in reels: Inspect `lib/models/reel_model.dart` and `lib/screens/creator/creator_studio_screen.dart:351–454`.
