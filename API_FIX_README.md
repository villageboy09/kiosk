# API Fix: Stage-Specific Problems Not Showing

## Problem Statement

Stage-specific diseases, pests, and deficiencies are not visible in the crop advisory sections. While crop stages are visible and working correctly, the problems for each stage are not being returned by the API.

## Root Cause Analysis

The deployed API (`api.php` on your production server) uses **incorrect column names** that don't exist in the `rice_problems` database table.

### Column Name Mismatch

| What the deployed API uses | What the database actually has |
|---------------------------|-------------------------------|
| `name_en` | `problem_name_en` |
| `name_te` | `problem_name_te` |
| `image_url` | `image_url1`, `image_url2`, `image_url3` |

### The Faulty Code (in deployed api.php)

```php
// Line 384 - WRONG column names
$nameColumn = $lang === 'en' ? 'name_en' : 'name_te';

// Line 388 - WRONG column name for image
$sql = "SELECT rp.id, rp.$nameColumn as name, rp.image_url 
        FROM rice_problems rp
        JOIN problem_stages ps ON rp.id = ps.problem_id 
        WHERE 1=1";
```

This causes the SQL query to fail because:
1. Column `name_en` doesn't exist → should be `problem_name_en`
2. Column `name_te` doesn't exist → should be `problem_name_te`
3. Column `image_url` doesn't exist → should be `image_url1`

## Solution

Replace the `getProblems` function in your deployed `api.php` with the corrected version.

### Corrected Code

```php
function getProblems($pdo) {
    $cropId = $_GET['crop_id'] ?? null;
    $stageId = $_GET['stage_id'] ?? null;
    $lang = $_GET['lang'] ?? 'te';
    
    // CORRECT column names
    $nameField = ($lang === 'en') ? 'problem_name_en' : 'problem_name_te';
    
    if ($stageId) {
        $sql = "
            SELECT DISTINCT
                rp.id,
                rp.$nameField as name,
                rp.problem_name_te as name_te,
                rp.problem_name_en as name_en,
                rp.category,
                rp.crop_id,
                rp.image_url1,
                rp.image_url2,
                rp.image_url3
            FROM rice_problems rp
            INNER JOIN problem_stages ps ON rp.id = ps.problem_id
            WHERE ps.stage_id = ?
        ";
        $params = [$stageId];
        
        if ($cropId) {
            $sql .= " AND rp.crop_id = ?";
            $params[] = $cropId;
        }
        
        $sql .= " ORDER BY rp.category, rp.id";
    } else if ($cropId) {
        $sql = "
            SELECT 
                rp.id,
                rp.$nameField as name,
                rp.problem_name_te as name_te,
                rp.problem_name_en as name_en,
                rp.category,
                rp.crop_id,
                rp.image_url1,
                rp.image_url2,
                rp.image_url3
            FROM rice_problems rp
            WHERE rp.crop_id = ?
            ORDER BY rp.category, rp.id
        ";
        $params = [$cropId];
    } else {
        $sql = "
            SELECT 
                rp.id,
                rp.$nameField as name,
                rp.problem_name_te as name_te,
                rp.problem_name_en as name_en,
                rp.category,
                rp.crop_id,
                rp.image_url1,
                rp.image_url2,
                rp.image_url3
            FROM rice_problems rp
            ORDER BY rp.category, rp.id
        ";
        $params = [];
    }
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $problems = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'problems' => $problems]);
}
```

## How to Apply the Fix

### Option 1: Update the deployed api.php directly

1. SSH into your production server
2. Navigate to your API directory
3. Open `api.php` in an editor
4. Find the `getProblems` function (around line 379)
5. Replace it with the corrected version above
6. Save and test

### Option 2: Use the repository version

The repository (`/api/api.php`) already has the correct column names. Simply deploy the latest version from the repository:

```bash
# On your production server
cd /path/to/your/api
git pull origin main
```

## Testing the Fix

After applying the fix, test with these API calls:

```bash
# Test Rice Stage 1 (Germination)
curl "https://kiosk.cropsync.in/api/api.php?action=get_problems&crop_id=1&stage_id=1&lang=en"

# Test Rice Stage 2 (Seedling)
curl "https://kiosk.cropsync.in/api/api.php?action=get_problems&crop_id=1&stage_id=2&lang=en"

# Test Sunflower Stage 26 (Germination)
curl "https://kiosk.cropsync.in/api/api.php?action=get_problems&crop_id=12&stage_id=26&lang=en"
```

Expected response should include problems with proper `name`, `category`, and `image_url1` fields.

## Database Schema Reference

### rice_problems table

| Column | Type | Description |
|--------|------|-------------|
| id | int | Primary key |
| problem_name_te | varchar(255) | Problem name in Telugu |
| problem_name_en | varchar(255) | Problem name in English |
| category | varchar(50) | Category (Pest, Disease, Deficiency, etc.) |
| crop_id | int | Foreign key to crops table |
| image_url1 | varchar(255) | Primary image URL |
| image_url2 | varchar(255) | Secondary image URL |
| image_url3 | varchar(255) | Tertiary image URL |

### problem_stages table

| Column | Type | Description |
|--------|------|-------------|
| id | int | Primary key |
| problem_id | int | Foreign key to rice_problems.id |
| stage_id | int | Foreign key to CropStages.StageID |

### CropStages table

| Column | Type | Description |
|--------|------|-------------|
| StageID | int | Primary key |
| crop_id | int | Foreign key to crops table |
| StageName | varchar | Stage name in Telugu |
| StageName_en | varchar | Stage name in English |

## Verified Data Mappings

The database has correct problem-to-stage mappings:

| Crop | Stage ID | Stage Name | Number of Problems |
|------|----------|------------|-------------------|
| Rice | 1 | Germination | 9 problems |
| Rice | 2 | Seedling | 14 problems |
| Rice | 3 | Tillering | 11 problems |
| Rice | 4 | Stem Elongation | 3 problems |
| Rice | 7 | Flowering | 2 problems |
| Rice | 8 | Grain Filling | 3 problems |
| Sunflower | 26 | Germination | 4 problems |
| Sunflower | 27 | Vegetative | 19 problems |
| Sunflower | 28 | Bud Initiation | 2 problems |
| Sunflower | 29 | Flowering | 7 problems |
| Sunflower | 30 | Seed Filling | 5 problems |
| Sunflower | 31 | Maturity | 3 problems |

The data is complete - the only issue is the column name mismatch in the API.
