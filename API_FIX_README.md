# Complete Crop Advisory API Fix

## Problem Statement

Stage-specific diseases, pests, and deficiencies were not visible in the crop advisory sections. The complete flow should be:

1. **Select Crop** → Display all stages for that crop
2. **Select Stage** → Display diseases, pests, and deficiencies specific to that stage of that crop
3. **Tap on Problem** → Display advisory components (remedies) specific to that problem AND that stage

## Root Cause Analysis

### Issue 1: Wrong Column Names (Original Issue)
The deployed API used incorrect column names that don't exist in the database:
- `name_en`/`name_te` instead of `problem_name_en`/`problem_name_te`
- `image_url` instead of `image_url1`, `image_url2`, `image_url3`

### Issue 2: Missing problem_stage_id (New Issue)
The API was not returning `problem_stage_id` which is required to fetch stage-specific advisory components.

### Issue 3: Advisory Components Not Stage-Filtered
The `getAdvisoryComponents` function was not properly filtering by `problem_stage_id`.

## Database Relationships

```
crops (id)
    │
    └──► CropStages (crop_id → StageID)
            │
            └──► problem_stages (stage_id, problem_id) ──► id = problem_stage_id
                    │
                    └──► rice_problems (id, crop_id)
                            │
                            └──► crop_advisories (problem_id → id)
                                    │
                                    └──► advisory_components (advisory_id, problem_stage_id)
```

### Key Table: problem_stages
This junction table is CRITICAL. It maps problems to stages and provides the `problem_stage_id`:
- `id` - The problem_stage_id (used for stage-specific advisory components)
- `problem_id` - Foreign key to rice_problems.id
- `stage_id` - Foreign key to CropStages.StageID

### Key Table: advisory_components
This table stores remedies with stage-specific filtering:
- `advisory_id` - Foreign key to crop_advisories.id
- `problem_stage_id` - Foreign key to problem_stages.id (stage-specific)
- `stage_scope` - General stage category (Nursery, Vegetative, Reproductive, Ripening, All Stages)

## Complete API Flow

### Step 1: Get Crops
```
GET /api.php?action=get_crops&lang=en
```
Returns: List of all crops

### Step 2: Get Stages for a Crop
```
GET /api.php?action=get_crop_stages&crop_id=1&lang=en
```
Returns: All stages for Rice (crop_id=1)

### Step 3: Get Problems for a Stage (FIXED)
```
GET /api.php?action=get_problems&crop_id=1&stage_id=2&lang=en
```
Returns: Problems for Rice Seedling stage, **including problem_stage_id**

Example response:
```json
{
  "success": true,
  "problems": [
    {
      "id": 5,
      "name": "Blast",
      "category": "Fungal Disease",
      "crop_id": 1,
      "image_url1": "...",
      "problem_stage_id": 132,  // <-- CRITICAL: This is needed for step 5
      "stage_id": 2
    }
  ]
}
```

### Step 4: Get Advisory for a Problem (FIXED)
```
GET /api.php?action=get_advisories&problem_id=5&stage_id=2&lang=en
```
Returns: Advisory with **problem_stage_id** for stage-specific components

Example response:
```json
{
  "success": true,
  "advisory": {
    "id": 5,
    "problem_id": 5,
    "title": "Blast Management",
    "symptoms": "...",
    "problem_stage_id": 132,  // <-- CRITICAL: Pass this to step 5
    "stage_id": 2
  }
}
```

### Step 5: Get Stage-Specific Advisory Components (FIXED)
```
GET /api.php?action=get_advisory_components&advisory_id=5&problem_stage_id=132&stage_scope=Vegetative&lang=en
```
Returns: Only components that are:
1. Specific to problem_stage_id=132, OR
2. General (problem_stage_id IS NULL), AND
3. Match stage_scope=Vegetative OR stage_scope='All Stages'

## Changes Made

### 1. getProblems Function
**Before:** Did not return `problem_stage_id`
**After:** Returns `problem_stage_id` from the `problem_stages` junction table

```php
// NEW: Include ps.id as problem_stage_id
SELECT DISTINCT
    rp.id,
    rp.problem_name_en as name,
    ...
    ps.id as problem_stage_id,  // <-- NEW
    ps.stage_id                  // <-- NEW
FROM rice_problems rp
INNER JOIN problem_stages ps ON rp.id = ps.problem_id
WHERE ps.stage_id = ?
```

### 2. getAdvisories Function
**Before:** Did not return `problem_stage_id`
**After:** Accepts `stage_id` parameter and returns `problem_stage_id`

```php
// NEW: Look up problem_stage_id if stage_id is provided
if ($stageId) {
    $stmt = $pdo->prepare("
        SELECT id as problem_stage_id 
        FROM problem_stages 
        WHERE problem_id = ? AND stage_id = ?
    ");
    $stmt->execute([$problemId, $stageId]);
    $psResult = $stmt->fetch(PDO::FETCH_ASSOC);
    $advisory['problem_stage_id'] = $psResult['problem_stage_id'];
}
```

### 3. getAdvisoryComponents Function
**Before:** Only filtered by `advisory_id` and `stage_scope`
**After:** Also filters by `problem_stage_id` for stage-specific components

```php
// NEW: Filter by problem_stage_id
if ($problemStageId) {
    $sql .= " AND (problem_stage_id = ? OR problem_stage_id IS NULL)";
    $params[] = $problemStageId;
}
```

## Flutter Integration

### In your advisory_screen.dart or similar:

```dart
// When user selects a problem from the list
void onProblemSelected(Map<String, dynamic> problem) async {
  final problemId = problem['id'];
  final stageId = problem['stage_id'];
  final problemStageId = problem['problem_stage_id'];
  
  // Get advisory with problem_stage_id
  final advisory = await ApiService.getAdvisories(
    problemId: problemId,
    stageId: stageId,
    lang: currentLocale,
  );
  
  // Navigate to advisory details
  Navigator.push(context, MaterialPageRoute(
    builder: (context) => AdvisoryDetailsScreen(
      advisory: advisory,
      problemStageId: problemStageId,
    ),
  ));
}
```

### In your advisory_details.dart:

```dart
// Fetch stage-specific components
Future<void> loadComponents() async {
  final components = await ApiService.getAdvisoryComponents(
    advisoryId: widget.advisory['id'],
    problemStageId: widget.problemStageId,  // <-- Pass this!
    stageScope: _getStageScope(),  // e.g., 'Vegetative'
    lang: currentLocale,
  );
  
  setState(() {
    _components = components;
  });
}
```

### Update ApiService.dart:

```dart
// Updated getProblems - now returns problem_stage_id
static Future<List<Map<String, dynamic>>> getProblems({
  int? cropId,
  int? stageId,
  String lang = 'te',
}) async {
  String url = '$baseUrl/api.php?action=get_problems&lang=$lang';
  if (cropId != null) url += '&crop_id=$cropId';
  if (stageId != null) url += '&stage_id=$stageId';
  // Response now includes problem_stage_id for each problem
  ...
}

// Updated getAdvisories - now accepts stage_id and returns problem_stage_id
static Future<Map<String, dynamic>?> getAdvisories(
  int problemId, {
  int? stageId,  // <-- NEW parameter
  String lang = 'te',
}) async {
  String url = '$baseUrl/api.php?action=get_advisories&problem_id=$problemId&lang=$lang';
  if (stageId != null) url += '&stage_id=$stageId';  // <-- NEW
  ...
}

// Updated getAdvisoryComponents - now accepts problem_stage_id
static Future<List<Map<String, dynamic>>> getAdvisoryComponents(
  int advisoryId, {
  int? problemStageId,  // <-- NEW parameter
  String? stageScope,
  String lang = 'te',
}) async {
  String url = '$baseUrl/api.php?action=get_advisory_components&advisory_id=$advisoryId&lang=$lang';
  if (problemStageId != null) url += '&problem_stage_id=$problemStageId';  // <-- NEW
  if (stageScope != null) url += '&stage_scope=$stageScope';
  ...
}
```

## Testing

### Test Rice Stage 2 (Seedling) Problems:
```bash
curl "https://kiosk.cropsync.in/api/api.php?action=get_problems&crop_id=1&stage_id=2&lang=en"
```

### Test Advisory with Stage:
```bash
curl "https://kiosk.cropsync.in/api/api.php?action=get_advisories&problem_id=5&stage_id=2&lang=en"
```

### Test Stage-Specific Components:
```bash
curl "https://kiosk.cropsync.in/api/api.php?action=get_advisory_components&advisory_id=5&problem_stage_id=132&stage_scope=Vegetative&lang=en"
```

## Deployment

1. Copy the updated `api/api.php` to your production server
2. Update your Flutter app's `ApiService.dart` to pass the new parameters
3. Update your UI to store and pass `problem_stage_id` through the flow

## Summary

The fix ensures that:
1. ✅ Selecting a crop shows all its stages
2. ✅ Selecting a stage shows only problems mapped to that stage
3. ✅ Each problem includes its `problem_stage_id`
4. ✅ Advisory components are filtered by `problem_stage_id` for stage-specific remedies
5. ✅ General components (with NULL problem_stage_id) are still included
