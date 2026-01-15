<?php
/**
 * CORRECTED getProblems function for CropSync Kiosk API
 * 
 * ISSUE: The deployed API uses incorrect column names:
 *   - Uses 'name_en', 'name_te' instead of 'problem_name_en', 'problem_name_te'
 *   - Uses 'image_url' instead of 'image_url1', 'image_url2', 'image_url3'
 * 
 * This causes the SQL query to fail silently, returning empty results.
 * 
 * SOLUTION: Replace the getProblems function in your deployed api.php with this corrected version.
 */

function getProblems($pdo) {
    $cropId = $_GET['crop_id'] ?? null;
    $stageId = $_GET['stage_id'] ?? null;
    $lang = $_GET['lang'] ?? 'te';
    
    // CORRECT column names from rice_problems table:
    // - problem_name_en (NOT name_en)
    // - problem_name_te (NOT name_te)
    // - image_url1, image_url2, image_url3 (NOT image_url)
    $nameField = ($lang === 'en') ? 'problem_name_en' : 'problem_name_te';
    
    if ($stageId) {
        // Get problems for a specific stage using problem_stages junction table
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
        // Get all problems for a crop
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
        // Get all problems
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
