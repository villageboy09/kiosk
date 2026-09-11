<?php
/**
 * CropSync Central Catalog Dashboard - Agri Shop & Seed Varieties Management
 * 
 * Unified single-page administrative dashboard to manage products, seed varieties,
 * categories, crops master, vendors, advertisers, and farmer demand irrespective of who uploaded them.
 * 
 * Styled with Google Sans typography, Phosphor Icons, and 100% Alpine.js Custom Dropdowns.
 */

session_start();

// -------------------------------------------------------------
// 1. Database Connection & Environment Setup
// -------------------------------------------------------------
$configPaths = [
    __DIR__ . '/config.php',
    __DIR__ . '/api/config.php',
    __DIR__ . '/../config.php',
    dirname(__DIR__) . '/config.php',
];

foreach ($configPaths as $cp) {
    if (file_exists($cp)) {
        require_once $cp;
        break;
    }
}

if (!isset($pdo) || !($pdo instanceof PDO)) {
    $servername = isset($servername) ? $servername : "127.0.0.1";
    $username   = isset($username) ? $username : "u893187665_arjun";
    $password   = isset($password) ? $password : "CropSync@2024";
    $dbname     = isset($dbname) ? $dbname : "u893187665_kiosk";

    try {
        $dsn = "mysql:host=$servername;dbname=$dbname;charset=utf8mb4";
        $pdo = new PDO($dsn, $username, $password, [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
        ]);
        $pdo->exec("SET time_zone = '+05:30'");
    } catch (PDOException $e) {
        $dbError = $e->getMessage();
    }
}

// Ensure schema columns & multilingual tables are present (Gated by lockfile for high speed)
$schemaLockFile = __DIR__ . '/.catalog_schema_migrated_v4';
if (isset($pdo) && $pdo instanceof PDO && (!file_exists($schemaLockFile) || isset($_GET['recheck_schema']))) {
    try {
        $pdo->exec("SET NAMES utf8mb4");

        // 1. Convert products table category column from legacy restrictive ENUM to VARCHAR(100)
        try {
            $pdo->exec("ALTER TABLE `products` MODIFY COLUMN `category` VARCHAR(100) NOT NULL DEFAULT 'General'");
        } catch (Throwable $e) {}

        // 2. Multilingual product categories table
        $pdo->exec("CREATE TABLE IF NOT EXISTS `product_categories` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `category_name_en` VARCHAR(100) NOT NULL,
            `category_name_te` VARCHAR(100) NOT NULL,
            `category_name_hi` VARCHAR(100) DEFAULT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX `idx_cat_en` (`category_name_en`),
            INDEX `idx_cat_te` (`category_name_te`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;");

        // Seed initial known categories if empty
        $catCount = $pdo->query("SELECT COUNT(*) FROM `product_categories`")->fetchColumn();
        if ($catCount == 0) {
            $initialCats = [
                ['en' => 'Machinery', 'te' => 'మెషీన్', 'hi' => 'मशीन'],
                ['en' => 'Farm Tools', 'te' => 'పనిముట్లు', 'hi' => 'उपकरण'],
                ['en' => 'Seeds & Fertilizers', 'te' => 'విత్తనాలు/ఎరువులు', 'hi' => 'बीज और उर्वरक'],
                ['en' => 'Insecticide', 'te' => 'పురుగుమందులు', 'hi' => 'कीटनाशक'],
                ['en' => 'Fungicide', 'te' => 'శిలీంద్ర సంహారిణి', 'hi' => 'कवकनाशी'],
                ['en' => 'Herbicide', 'te' => 'కలుపు సంహారిణి', 'hi' => 'शाकनाशी'],
            ];
            $cStmt = $pdo->prepare("INSERT INTO `product_categories` (`category_name_en`, `category_name_te`, `category_name_hi`) VALUES (?, ?, ?)");
            foreach ($initialCats as $ic) {
                $cStmt->execute([$ic['en'], $ic['te'], $ic['hi']]);
            }
        }

        // Check products table extra columns (including category_en & category_hi)
        $productCols = [
            'mrp' => "ALTER TABLE `products` ADD COLUMN `mrp` DECIMAL(10,2) DEFAULT NULL",
            'in_stock' => "ALTER TABLE `products` ADD COLUMN `in_stock` TINYINT(1) DEFAULT 1",
            'is_active' => "ALTER TABLE `products` ADD COLUMN `is_active` TINYINT(1) DEFAULT 1",
            'region_id' => "ALTER TABLE `products` ADD COLUMN `region_id` INT DEFAULT NULL",
            'product_name_en' => "ALTER TABLE `products` ADD COLUMN `product_name_en` VARCHAR(150) DEFAULT NULL",
            'product_name_hi' => "ALTER TABLE `products` ADD COLUMN `product_name_hi` VARCHAR(150) DEFAULT NULL",
            'product_description_en' => "ALTER TABLE `products` ADD COLUMN `product_description_en` TEXT DEFAULT NULL",
            'product_description_hi' => "ALTER TABLE `products` ADD COLUMN `product_description_hi` TEXT DEFAULT NULL",
            'category_en' => "ALTER TABLE `products` ADD COLUMN `category_en` VARCHAR(100) DEFAULT NULL",
            'category_hi' => "ALTER TABLE `products` ADD COLUMN `category_hi` VARCHAR(100) DEFAULT NULL",
        ];
        foreach ($productCols as $cCol => $cSql) {
            try {
                $chk = $pdo->query("SHOW COLUMNS FROM `products` LIKE '$cCol'");
                if (!$chk || !$chk->fetch()) {
                    $pdo->exec($cSql);
                }
            } catch (Throwable $e) {}
        }

        // 3. Auto-populate missing multilingual category values in existing products from product_categories
        try {
            $pdo->exec("
                UPDATE `products` p
                JOIN `product_categories` pc ON (p.category = pc.category_name_te OR p.category = pc.category_name_en)
                SET p.category_en = IF(p.category_en IS NULL OR p.category_en = '', pc.category_name_en, p.category_en),
                    p.category_hi = IF(p.category_hi IS NULL OR p.category_hi = '', pc.category_name_hi, p.category_hi)
                WHERE (p.category_en IS NULL OR p.category_en = '') OR (p.category_hi IS NULL OR p.category_hi = '')
            ");
            $pdo->exec("
                UPDATE `products` p
                JOIN `product_categories` pc ON p.category = pc.category_name_en
                SET p.category = pc.category_name_te
                WHERE pc.category_name_te IS NOT NULL AND pc.category_name_te != ''
            ");
        } catch (Throwable $e) {}

        // Check seed_varieties table extra columns
        $varietyCols = [
            'average_yield'    => "ALTER TABLE `seed_varieties` ADD COLUMN `average_yield` DECIMAL(10,2) DEFAULT NULL",
            'growth_duration'  => "ALTER TABLE `seed_varieties` ADD COLUMN `growth_duration` SMALLINT(6) DEFAULT NULL",
            'variety_name_hi'  => "ALTER TABLE `seed_varieties` ADD COLUMN `variety_name_hi` VARCHAR(150) DEFAULT NULL",
            'details_hi'       => "ALTER TABLE `seed_varieties` ADD COLUMN `details_hi` TEXT DEFAULT NULL",
            'region_en'        => "ALTER TABLE `seed_varieties` ADD COLUMN `region_en` VARCHAR(255) DEFAULT NULL",
            'region_te'        => "ALTER TABLE `seed_varieties` ADD COLUMN `region_te` VARCHAR(255) DEFAULT NULL",
            'region_hi'        => "ALTER TABLE `seed_varieties` ADD COLUMN `region_hi` VARCHAR(255) DEFAULT NULL",
            'sowing_period_en' => "ALTER TABLE `seed_varieties` ADD COLUMN `sowing_period_en` VARCHAR(255) DEFAULT NULL",
            'sowing_period_te' => "ALTER TABLE `seed_varieties` ADD COLUMN `sowing_period_te` VARCHAR(255) DEFAULT NULL",
            'sowing_period_hi' => "ALTER TABLE `seed_varieties` ADD COLUMN `sowing_period_hi` VARCHAR(255) DEFAULT NULL",
        ];
        foreach ($varietyCols as $vCol => $vSql) {
            try {
                $chk = $pdo->query("SHOW COLUMNS FROM `seed_varieties` LIKE '$vCol'");
                if (!$chk || !$chk->fetch()) {
                    $pdo->exec($vSql);
                }
            } catch (Throwable $e) {}
        }

        // Initialize multilingual region & sowing period from existing values if empty
        try {
            $pdo->exec("UPDATE `seed_varieties` SET region_en = region WHERE (region_en IS NULL OR region_en = '') AND region REGEXP '^[A-Za-z0-9 ,./-]+$'");
            $pdo->exec("UPDATE `seed_varieties` SET region_te = region WHERE (region_te IS NULL OR region_te = '') AND region IS NOT NULL AND region != '' AND (region_en IS NULL OR region_en = '')");
            $pdo->exec("UPDATE `seed_varieties` SET sowing_period_en = sowing_period WHERE (sowing_period_en IS NULL OR sowing_period_en = '') AND sowing_period REGEXP '^[A-Za-z0-9 ,./-]+$'");
            $pdo->exec("UPDATE `seed_varieties` SET sowing_period_te = sowing_period WHERE (sowing_period_te IS NULL OR sowing_period_te = '') AND sowing_period IS NOT NULL AND sowing_period != '' AND (sowing_period_en IS NULL OR sowing_period_en = '')");
        } catch (Throwable $e) {}

        // Add performance indexes if missing
        $perfIndexes = [
            "CREATE INDEX `idx_prod_active` ON `products` (`is_active`, `in_stock`)",
            "CREATE INDEX `idx_prod_cat` ON `products` (`category`(50))",
            "CREATE INDEX `idx_var_crop` ON `seed_varieties` (`crop_name`(50))",
            "CREATE INDEX `idx_vl_var` ON `vendor_listings` (`seed_variety_id`, `is_active`)",
            "CREATE INDEX `idx_bk_var` ON `bookings` (`seed_variety_id`)"
        ];
        foreach ($perfIndexes as $idxSql) {
            try { $pdo->exec($idxSql); } catch (Throwable $e) {}
        }

        // Write migration lock file
        @file_put_contents($schemaLockFile, date('Y-m-d H:i:s'));
    } catch (Throwable $e) {}
}

// -------------------------------------------------------------
// 2. Flash Notification Helpers
// -------------------------------------------------------------
function setFlash($message, $type = 'success') {
    $_SESSION['flash_msg'] = ['text' => $message, 'type' => $type];
}

function getFlash() {
    if (isset($_SESSION['flash_msg'])) {
        $msg = $_SESSION['flash_msg'];
        unset($_SESSION['flash_msg']);
        return $msg;
    }
    return null;
}

// -------------------------------------------------------------
// 3. File Upload & Auto-Translation Helpers
// -------------------------------------------------------------
function uploadCatalogFile($fileInputName, $subfolder = 'products') {
    $allowed = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'svg', 'mp4', 'mov', 'webm', 'avi', 'mkv', 'm4v'];
    $targetDir = __DIR__ . '/' . trim($subfolder, '/') . '/';
    if (!is_dir($targetDir)) {
        @mkdir($targetDir, 0777, true);
    }

    if (isset($_FILES[$fileInputName]) && $_FILES[$fileInputName]['error'] === UPLOAD_ERR_OK) {
        $ext = strtolower(pathinfo($_FILES[$fileInputName]['name'], PATHINFO_EXTENSION));
        if (in_array($ext, $allowed)) {
            $fileName = time() . '_' . rand(1000, 9999) . '.' . $ext;
            if (move_uploaded_file($_FILES[$fileInputName]['tmp_name'], $targetDir . $fileName)) {
                return 'https://kiosk.cropsync.in/' . trim($subfolder, '/') . '/' . $fileName;
            }
        }
    }
    return null;
}

function getTranslationCacheFile() {
    return __DIR__ . '/.translation_cache.json';
}

function loadTranslationCache() {
    static $cache = null;
    if ($cache !== null) return $cache;
    $file = getTranslationCacheFile();
    if (file_exists($file)) {
        $content = @file_get_contents($file);
        $decoded = json_decode($content, true);
        if (is_array($decoded)) {
            $cache = $decoded;
            return $cache;
        }
    }
    $cache = [];
    return $cache;
}

function saveTranslationCache($cache) {
    $file = getTranslationCacheFile();
    @file_put_contents($file, json_encode($cache, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT));
}

function smartTranslateText($text, $targetLang = 'te', $sourceLang = 'en') {
    $text = trim($text);
    if ($text === '') return '';
    if ($sourceLang === $targetLang) return $text;

    $cacheKey = strtolower($sourceLang) . ':' . strtolower($targetLang) . ':' . mb_strtolower($text, 'UTF-8');
    $cache = loadTranslationCache();
    if (isset($cache[$cacheKey])) {
        return $cache[$cacheKey];
    }

    // 1. Core Agricultural, District, Seasonal Dictionary (Instant 0ms lookup)
    static $dict = [
        // Categories & Products
        'machinery' => ['te' => 'మెషీన్', 'hi' => 'मशीन'],
        'farm tools' => ['te' => 'పనిముట్లు', 'hi' => 'उपकरण'],
        'tools' => ['te' => 'పనిముట్లు', 'hi' => 'उपकरण'],
        'seeds & fertilizers' => ['te' => 'విత్తనాలు/ఎరువులు', 'hi' => 'बीज और उर्वरक'],
        'seeds and fertilizers' => ['te' => 'విత్తనాలు మరియు ఎరువులు', 'hi' => 'बीज और उर्वरक'],
        'seeds' => ['te' => 'విత్తనాలు', 'hi' => 'बीज'],
        'fertilizers' => ['te' => 'ఎరువులు', 'hi' => 'उर्वरक'],
        'fertilizer' => ['te' => 'ఎరువు', 'hi' => 'उर्वरक'],
        'insecticide' => ['te' => 'పురుగుమందులు', 'hi' => 'कीटनाशक'],
        'fungicide' => ['te' => 'శిలీంద్ర సంహారిణి', 'hi' => 'कवकनाशी'],
        'herbicide' => ['te' => 'కలుపు సంహారిణి', 'hi' => 'शाकनाशी'],
        'pesticide' => ['te' => 'పురుగుమందు', 'hi' => 'कीटनाशक'],
        'pesticides' => ['te' => 'పురుగుమందులు', 'hi' => 'कीटनाशक'],
        'bio-fertilizers' => ['te' => 'సేంద్రీయ ఎరువులు', 'hi' => 'जैव उर्वरक'],
        'bio fertilizers' => ['te' => 'సేంద్రీయ ఎరువులు', 'hi' => 'जैव उर्वरक'],
        'growth promoters' => ['te' => 'మొక్కల పెరుగుదల ఉత్ప్రేరకాలు', 'hi' => 'पौध वृद्धि प्रवर्तक'],
        'irrigation' => ['te' => 'నీటి పారుదల పరికరాలు', 'hi' => 'सिंचाई उपकरण'],
        'spraying equipment' => ['te' => 'స్ప్రేయింగ్ పరికరాలు', 'hi' => 'छिड़काव उपकरण'],
        'harvesting tools' => ['te' => 'కోత పనిముట్లు', 'hi' => 'कटाई उपकरण'],
        'organic inputs' => ['te' => 'సేంద్రీయ ఉత్పత్తులు', 'hi' => 'जैविक उत्पाद'],
        'general' => ['te' => 'సాధారణ', 'hi' => 'सामान्य'],

        // Common Crops
        'paddy' => ['te' => 'వరి', 'hi' => 'धान'],
        'rice' => ['te' => 'వరి', 'hi' => 'चावल'],
        'cotton' => ['te' => 'పత్తి', 'hi' => 'कपास'],
        'chilli' => ['te' => 'మిరప', 'hi' => 'मिर्च'],
        'chili' => ['te' => 'మిరప', 'hi' => 'मिर्च'],
        'maize' => ['te' => 'మొక్కజొన్న', 'hi' => 'मक्का'],
        'corn' => ['te' => 'మొక్కజొన్న', 'hi' => 'मक्का'],
        'red gram' => ['te' => 'కందులు', 'hi' => 'अरहर / तूर'],
        'bengal gram' => ['te' => 'శనగలు', 'hi' => 'चना'],
        'black gram' => ['te' => 'మినుములు', 'hi' => 'उड़द'],
        'green gram' => ['te' => 'పెసలు', 'hi' => 'मूंग'],
        'groundnut' => ['te' => 'వేరుశనగ', 'hi' => 'मूंगफली'],
        'peanut' => ['te' => 'వేరుశనగ', 'hi' => 'मूंगफली'],
        'soybean' => ['te' => 'సోయాబీన్', 'hi' => 'सोयाबीन'],
        'sugarcane' => ['te' => 'చెరకు', 'hi' => 'गन्ना'],
        'turmeric' => ['te' => 'పసుపు', 'hi' => 'हल्दी'],
        'tomato' => ['te' => 'టమోటా', 'hi' => 'टमाटर'],
        'onion' => ['te' => 'ఉల్లిపాయ', 'hi' => 'प्याज'],
        'brinjal' => ['te' => 'వంకాయ', 'hi' => 'बैंगन'],
        'eggplant' => ['te' => 'వంకాయ', 'hi' => 'बैंगन'],
        'bhendi' => ['te' => 'బెండకాయ', 'hi' => 'भिंडी'],
        'okra' => ['te' => 'బెండకాయ', 'hi' => 'भिंडी'],
        'wheat' => ['te' => 'గోధుమలు', 'hi' => 'गेहूं'],
        'mustard' => ['te' => 'ఆవాలు', 'hi' => 'सरसों'],
        'castor' => ['te' => 'ఆముదం', 'hi' => 'अरंडी'],
        'sunflower' => ['te' => 'పొద్దుతిరుగుడు', 'hi' => 'सूरजमुखी'],
        'sesame' => ['te' => 'నువ్వులు', 'hi' => 'तिल'],
        'potato' => ['te' => 'బంగాళాదుంప', 'hi' => 'आलू'],
        'cabbage' => ['te' => 'క్యాబేజీ', 'hi' => 'पत्तागोभी'],
        'cauliflower' => ['te' => 'కాలీఫ్లవర్', 'hi' => 'फूलगोभी'],
        'banana' => ['te' => 'అరటి', 'hi' => 'केला'],
        'mango' => ['te' => 'మామిడి', 'hi' => 'आम'],

        // Months & Seasons
        'january' => ['te' => 'జనవరి', 'hi' => 'जनवरी'],
        'february' => ['te' => 'ఫిబ్రవరి', 'hi' => 'फ़रवरी'],
        'march' => ['te' => 'మార్చి', 'hi' => 'मार्च'],
        'april' => ['te' => 'ఏప్రిల్', 'hi' => 'अप्रैल'],
        'may' => ['te' => 'మే', 'hi' => 'मई'],
        'june' => ['te' => 'జూన్', 'hi' => 'जून'],
        'july' => ['te' => 'జూలై', 'hi' => 'जुलाई'],
        'august' => ['te' => 'ఆగస్టు', 'hi' => 'अगस्त'],
        'september' => ['te' => 'సెప్టెంబర్', 'hi' => 'सितंबर'],
        'october' => ['te' => 'అక్టోబర్', 'hi' => 'अक्टूबर'],
        'november' => ['te' => 'నవంబర్', 'hi' => 'नवंबर'],
        'december' => ['te' => 'డిసెంబర్', 'hi' => 'दिसंबर'],
        'kharif' => ['te' => 'ఖరీఫ్', 'hi' => 'खरीफ'],
        'rabi' => ['te' => 'రబీ', 'hi' => 'रबी'],
        'zaid' => ['te' => 'జైద్', 'hi' => 'जायद'],
        'summer' => ['te' => 'వేసవి', 'hi' => 'ग्रीष्मकाल'],
        'winter' => ['te' => 'శీతాకాలం', 'hi' => 'शीतकाल'],
        'monsoon' => ['te' => 'వర్షాకాలం', 'hi' => 'मानसून'],
        'spring' => ['te' => 'వసంతకాలం', 'hi' => 'बसंत'],
        'all seasons' => ['te' => 'అన్ని కాలాలు', 'hi' => 'सभी मौसम'],
        'throughout the year' => ['te' => 'సంవత్సరం పొడవునా', 'hi' => 'साल भर'],

        // Districts (Telangana & Andhra Pradesh)
        'all regions' => ['te' => 'అన్ని ప్రాంతాలు', 'hi' => 'सभी क्षेत्र'],
        'all districts' => ['te' => 'అన్ని జిల్లాలు', 'hi' => 'सभी जिले'],
        'telangana' => ['te' => 'తెలంగాణ', 'hi' => 'तेलंगाना'],
        'andhra pradesh' => ['te' => 'ఆంధ్రప్రదేశ్', 'hi' => 'आंध्र प्रदेश'],
        'nalgonda' => ['te' => 'నల్గొండ', 'hi' => 'नलगोंडा'],
        'warangal' => ['te' => 'వరంగల్', 'hi' => 'वारंगल'],
        'khammam' => ['te' => 'ఖమ్మం', 'hi' => 'खम्मम'],
        'karimnagar' => ['te' => 'కరీంనగర్', 'hi' => 'करीमनगर'],
        'nizamabad' => ['te' => 'నిజామాబాద్', 'hi' => 'निज़ामाबाद'],
        'mahabubnagar' => ['te' => 'మహబూబ్‌నగర్', 'hi' => 'महबूबनगर'],
        'medak' => ['te' => 'మెదక్', 'hi' => 'मेदक'],
        'adilabad' => ['te' => 'ఆదిలాబాద్', 'hi' => 'आदिलाबाद'],
        'rangareddy' => ['te' => 'రంగారెడ్డి', 'hi' => 'रंगारेड्डी'],
        'ranga reddy' => ['te' => 'రంగారెడ్డి', 'hi' => 'रंगारेड्डी'],
        'sangareddy' => ['te' => 'సంగారెడ్డి', 'hi' => 'संगारेड्डी'],
        'siddipet' => ['te' => 'సిద్ధిపేట', 'hi' => 'सिद्दिपेट'],
        'suryapet' => ['te' => 'సూర్యాపేట', 'hi' => 'सूर्यापेट'],
        'yadadri bhuvanagiri' => ['te' => 'యాదాద్రి భువనగిరి', 'hi' => 'यादाद्री भुवनगिरी'],
        'yadadri' => ['te' => 'యాదాద్రి', 'hi' => 'यादाद्री'],
        'jagtial' => ['te' => 'జగిత్యాల', 'hi' => 'जगतियाल'],
        'jangaon' => ['te' => 'జనగామ', 'hi' => 'जनगांव'],
        'jayashankar bhupalpally' => ['te' => 'జయశంకర్ భూపాలపల్లి', 'hi' => 'जयशंकर भूपालपल्ली'],
        'bhupalpally' => ['te' => 'భూపాలపల్లి', 'hi' => 'भूपालपल्ली'],
        'jogulamba gadwal' => ['te' => 'జోగులాంబ గద్వాల', 'hi' => 'जोगुलाम्बा गडवाल'],
        'gadwal' => ['te' => 'గద్వాల', 'hi' => 'गडवाल'],
        'kamareddy' => ['te' => 'కామారెడ్డి', 'hi' => 'कामारेड्डी'],
        'komaram bheem asifabad' => ['te' => 'కొమరం భీమ్ ఆసిఫాబాద్', 'hi' => 'कोमाराम भीम आसिफाबाद'],
        'asifabad' => ['te' => 'ఆసిఫాబాద్', 'hi' => 'आसिफाबाद'],
        'mahabubabad' => ['te' => 'మహబూబాబాద్', 'hi' => 'महबूबाबाद'],
        'mancherial' => ['te' => 'మంచిర్యాల', 'hi' => 'मंचेरियल'],
        'mulugu' => ['te' => 'ములుగు', 'hi' => 'ములుగు'],
        'nagarkurnool' => ['te' => 'నాగర్‌కర్నూల్', 'hi' => 'नागरकुरनूल'],
        'narayanpet' => ['te' => 'నారాయణపేట', 'hi' => 'नारायणपेट'],
        'nirmal' => ['te' => 'నిర్మల్', 'hi' => 'निर्मल'],
        'peddapalli' => ['te' => 'పెద్దపల్లి', 'hi' => 'पेद्दापल्ली'],
        'rajanna sircilla' => ['te' => 'రాజన్న సిరిసిల్ల', 'hi' => 'राजन्ना सिरसिल्ला'],
        'sircilla' => ['te' => 'సిరిసిల్ల', 'hi' => 'सिरसिल्ला'],
        'vikarabad' => ['te' => 'వికారాబాద్', 'hi' => 'विकाराबाद'],
        'wanaparthy' => ['te' => 'వనపర్తి', 'hi' => 'वनपर्ति'],
        'hanumakonda' => ['te' => 'హనుమకొండ', 'hi' => 'हनुमकोंडा'],
        'hanamkonda' => ['te' => 'హనుమకొండ', 'hi' => 'हनुमकोंडा'],
        'bhadradri kothagudem' => ['te' => 'భద్రాద్రి కొత్తగూడెం', 'hi' => 'भद्राद्री कोठागुडेम'],
        'kothagudem' => ['te' => 'కొత్తగూడెం', 'hi' => 'कोठागुडेम'],
        'hyderabad' => ['te' => 'హైదరాబాద్', 'hi' => 'हैदराबाद'],
        'guntur' => ['te' => 'గుంటూరు', 'hi' => 'गुंटूर'],
        'krishna' => ['te' => 'కృష్ణా', 'hi' => 'कृष्णा'],
        'east godavari' => ['te' => 'తూర్పు గోదావరి', 'hi' => 'पूर्वी गोदावरी'],
        'west godavari' => ['te' => 'పశ్చిమ గోదావరి', 'hi' => 'पश्चिम गोदावरी'],
        'visakhapatnam' => ['te' => 'విశాఖపట్నం', 'hi' => 'विशाखापत्तनम'],
        'vizag' => ['te' => 'వైజాగ్', 'hi' => 'विशाखापत्तनम'],
        'chittoor' => ['te' => 'చిత్తూరు', 'hi' => 'चित्तूर'],
        'anantapur' => ['te' => 'అనంతపురం', 'hi' => 'अनंतपुर'],
        'kurnool' => ['te' => 'కర్నూలు', 'hi' => 'कुरनूल'],
        'kadapa' => ['te' => 'కడప', 'hi' => 'कडपा'],
        'ysr kadapa' => ['te' => 'వైఎస్సార్ కడప', 'hi' => 'वाईएसआर कडपा'],
        'nellore' => ['te' => 'నెల్లూరు', 'hi' => 'नेल्लोर'],
        'prakasam' => ['te' => 'ప్రకాశం', 'hi' => 'प्रकाशम'],
        'srikakulam' => ['te' => 'శ్రీకాకుళం', 'hi' => 'श्रीकाकुलम'],
        'vizianagaram' => ['te' => 'విజయనగరం', 'hi' => 'विजयनगरम'],
        'tirupati' => ['te' => 'తిరుపతి', 'hi' => 'तिरुपति'],
        'annamayya' => ['te' => 'అన్నమయ్య', 'hi' => 'अन्नमय्या'],
        'ntr' => ['te' => 'ఎన్టీఆర్', 'hi' => 'एनटीआर'],
        'eluru' => ['te' => 'ఏలూరు', 'hi' => 'एलुरु'],
        'bapatla' => ['te' => 'బాపట్ల', 'hi' => 'बापटला'],
        'palnadu' => ['te' => 'పల్నాడు', 'hi' => 'पलनाडु'],
        'nandyal' => ['te' => 'నంద్యాల', 'hi' => 'नंद्याल'],
        'sri sathya sai' => ['te' => 'శ్రీ సత్యసాయి', 'hi' => 'श्री सत्य साई'],
        'konaseema' => ['te' => 'కోనసీమ', 'hi' => 'कोनासीमा'],
        'kakinada' => ['te' => 'కాకినాడ', 'hi' => 'काकीनाडा'],
        'alluri sitharama raju' => ['te' => 'అల్లూరి సీతారామరాజు', 'hi' => 'अल्लूरी सीताराम राजू'],
        'parvathipuram manyam' => ['te' => 'పార్వతీపురం మన్యం', 'hi' => 'पार्वतीपुरम मान्यम'],
        'anakapalli' => ['te' => 'అనకాపల్లి', 'hi' => 'अनकापल्ली']
    ];

    $norm = mb_strtolower($text, 'UTF-8');
    if (isset($dict[$norm][$targetLang])) {
        $result = $dict[$norm][$targetLang];
        $cache[$cacheKey] = $result;
        saveTranslationCache($cache);
        return $result;
    }

    // 2. Multi-token decomposition for comma-separated districts or words
    if (strpos($text, ',') !== false) {
        $tokens = array_map('trim', explode(',', $text));
        $translatedTokens = [];
        foreach ($tokens as $token) {
            if ($token === '') continue;
            $translatedTokens[] = smartTranslateText($token, $targetLang, $sourceLang);
        }
        $result = implode(', ', $translatedTokens);
        $cache[$cacheKey] = $result;
        saveTranslationCache($cache);
        return $result;
    }

    // 3. Composite periods: "June - July (Kharif)", "October to November"
    if (preg_match('/^([A-Za-z]+)\s*(-|to)\s*([A-Za-z]+)(\s*\((.*?)\))?$/i', $text, $matches)) {
        $start = smartTranslateText($matches[1], $targetLang, $sourceLang);
        $sep = ' - ';
        $end = smartTranslateText($matches[3], $targetLang, $sourceLang);
        $extra = !empty($matches[5]) ? ' (' . smartTranslateText($matches[5], $targetLang, $sourceLang) . ')' : '';
        $result = $start . $sep . $end . $extra;
        $cache[$cacheKey] = $result;
        saveTranslationCache($cache);
        return $result;
    }

    // 4. Online API Fallback with tight 2.5s timeout
    $ctx = stream_context_create([
        'http' => [
            'method' => 'GET',
            'header' => "User-Agent: CropSync-Catalog/2.0\r\n",
            'ignore_errors' => true,
            'timeout' => 2.5
        ],
        'ssl' => [
            'verify_peer' => false,
            'verify_peer_name' => false
        ]
    ]);

    $url = "https://api.mymemory.translated.net/get?q=" . urlencode($text) . "&langpair=" . urlencode($sourceLang) . "|" . urlencode($targetLang);
    $res = @file_get_contents($url, false, $ctx);
    if ($res) {
        $json = json_decode($res, true);
        if (!empty($json['responseData']['translatedText']) && stripos($json['responseData']['translatedText'], 'MYMEMORY WARNING') === false) {
            $trans = html_entity_decode($json['responseData']['translatedText'], ENT_QUOTES | ENT_HTML5, 'UTF-8');
            $cache[$cacheKey] = $trans;
            saveTranslationCache($cache);
            return $trans;
        }
    }

    return $text;
}

// Backward compatibility alias
function freeTranslateText($text, $targetLang = 'te', $sourceLang = 'en') {
    return smartTranslateText($text, $targetLang, $sourceLang);
}

// -------------------------------------------------------------
// 4. AJAX Endpoints
// -------------------------------------------------------------
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_GET['ajax_upload'])) {
    header('Content-Type: application/json');
    $type = $_GET['ajax_upload'];
    $folder = 'products';
    if ($type === 'seeds') {
        $folder = 'seed-images';
    } elseif ($type === 'crops') {
        $folder = 'crops';
    } elseif ($type === 'videos') {
        $folder = 'videos';
    } elseif ($type === 'vendors') {
        $folder = 'vendors';
    }
    $url = uploadCatalogFile('file', $folder);
    if (!empty($url)) {
        echo json_encode(['success' => true, 'url' => $url]);
    } else {
        echo json_encode(['success' => false, 'error' => 'File upload failed or unsupported extension.']);
    }
    exit();
}

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_GET['ajax_translate'])) {
    header('Content-Type: application/json');
    $sourceLang = trim($_POST['source_lang'] ?? 'en');
    $name   = trim($_POST['name'] ?? '');
    $desc   = trim($_POST['desc'] ?? '');
    $region = trim($_POST['region'] ?? '');
    $sowing = trim($_POST['sowing'] ?? '');

    try {
        $nameTe   = !empty($name) ? smartTranslateText($name, 'te', $sourceLang) : '';
        $nameHi   = !empty($name) ? smartTranslateText($name, 'hi', $sourceLang) : '';
        $descTe   = !empty($desc) ? smartTranslateText($desc, 'te', $sourceLang) : '';
        $descHi   = !empty($desc) ? smartTranslateText($desc, 'hi', $sourceLang) : '';
        $regionTe = !empty($region) ? smartTranslateText($region, 'te', $sourceLang) : '';
        $regionHi = !empty($region) ? smartTranslateText($region, 'hi', $sourceLang) : '';
        $sowingTe = !empty($sowing) ? smartTranslateText($sowing, 'te', $sourceLang) : '';
        $sowingHi = !empty($sowing) ? smartTranslateText($sowing, 'hi', $sourceLang) : '';

        echo json_encode([
            'success'   => true,
            'name_te'   => $nameTe,
            'name_hi'   => $nameHi,
            'desc_te'   => $descTe,
            'desc_hi'   => $descHi,
            'region_te' => $regionTe,
            'region_hi' => $regionHi,
            'sowing_te' => $sowingTe,
            'sowing_hi' => $sowingHi
        ]);
    } catch (Throwable $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
    exit();
}

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['ajax_action'])) {
    header('Content-Type: application/json');
    $ajaxAction = $_POST['ajax_action'];

    if ($ajaxAction === 'toggle_product_stock') {
        $pid = intval($_POST['product_id'] ?? 0);
        $newStock = intval($_POST['in_stock'] ?? 0);
        try {
            $pdo->prepare("UPDATE products SET in_stock = ? WHERE product_id = ?")->execute([$newStock, $pid]);
            echo json_encode(['success' => true, 'in_stock' => $newStock]);
        } catch (Throwable $e) {
            echo json_encode(['success' => false, 'error' => $e->getMessage()]);
        }
        exit();
    }

    if ($ajaxAction === 'toggle_product_active') {
        $pid = intval($_POST['product_id'] ?? 0);
        $newActive = intval($_POST['is_active'] ?? 0);
        try {
            $pdo->prepare("UPDATE products SET is_active = ? WHERE product_id = ?")->execute([$newActive, $pid]);
            echo json_encode(['success' => true, 'is_active' => $newActive]);
        } catch (Throwable $e) {
            echo json_encode(['success' => false, 'error' => $e->getMessage()]);
        }
        exit();
    }
}

// -------------------------------------------------------------
// 5. Handling Form Submissions (POST Actions)
// -------------------------------------------------------------
if ($_SERVER['REQUEST_METHOD'] === 'POST' && !isset($_GET['ajax_upload']) && !isset($_GET['ajax_translate'])) {
    $action = $_POST['action'] ?? '';

    // ==========================================
    // A. PRODUCTS CRUD (Irrespective of Advertiser)
    // ==========================================
    if ($action === 'save_product') {
        $productId = intval($_POST['product_id'] ?? 0);
        $advertiserId = intval($_POST['advertiser_id'] ?? 1);
        $category = trim($_POST['category'] ?? '');
        $categoryEn = trim($_POST['category_en'] ?? '');
        $categoryHi = trim($_POST['category_hi'] ?? '');

        // Fallbacks between Telugu and English
        if (empty($category) && !empty($categoryEn)) $category = $categoryEn;
        if (empty($categoryEn) && !empty($category)) $categoryEn = $category;
        if (empty($category)) $category = 'General';
        if (empty($categoryEn)) $categoryEn = 'General';

        // Auto-fill missing category_hi or sync from product_categories master table if available
        if (empty($categoryHi) || $category === $categoryEn) {
            try {
                $cLookup = $pdo->prepare("SELECT * FROM product_categories WHERE category_name_te = ? OR category_name_en = ? LIMIT 1");
                $cLookup->execute([$category, $categoryEn]);
                $cFound = $cLookup->fetch(PDO::FETCH_ASSOC);
                if ($cFound) {
                    if (empty($categoryHi) && !empty($cFound['category_name_hi'])) {
                        $categoryHi = $cFound['category_name_hi'];
                    }
                    if (!empty($cFound['category_name_te'])) {
                        $category = $cFound['category_name_te'];
                    }
                    if (!empty($cFound['category_name_en'])) {
                        $categoryEn = $cFound['category_name_en'];
                    }
                }
            } catch (Throwable $e) {}
        }

        // Ensure category column can store any string
        try {
            $pdo->exec("ALTER TABLE `products` MODIFY COLUMN `category` VARCHAR(100) NOT NULL DEFAULT 'General'");
        } catch (Throwable $e) {}

        $productCode = trim($_POST['product_code'] ?? '');
        $price = floatval($_POST['price'] ?? 0);
        $mrp = !empty($_POST['mrp']) ? floatval($_POST['mrp']) : null;
        $inStock = isset($_POST['in_stock']) ? 1 : 0;
        $isActive = isset($_POST['is_active']) ? 1 : 0;
        $regionId = !empty($_POST['region_id']) ? intval($_POST['region_id']) : null;

        $nameTe = trim($_POST['product_name'] ?? '');
        $nameEn = trim($_POST['product_name_en'] ?? '');
        $nameHi = trim($_POST['product_name_hi'] ?? '');
        if (empty($nameTe)) $nameTe = $nameEn;
        if (empty($nameEn)) $nameEn = $nameTe;

        $descTe = trim($_POST['product_description'] ?? '');
        $descEn = trim($_POST['product_description_en'] ?? '');
        $descHi = trim($_POST['product_description_hi'] ?? '');

        $img1 = trim($_POST['image_url_1'] ?? '');
        $img2 = trim($_POST['image_url_2'] ?? '');
        $img3 = trim($_POST['image_url_3'] ?? '');
        $videoUrl = trim($_POST['product_video_url'] ?? '');

        // File upload overrides
        $uploadedImg1 = uploadCatalogFile('image_file_1', 'products');
        if ($uploadedImg1) $img1 = $uploadedImg1;
        $uploadedImg2 = uploadCatalogFile('image_file_2', 'products');
        if ($uploadedImg2) $img2 = $uploadedImg2;
        $uploadedImg3 = uploadCatalogFile('image_file_3', 'products');
        if ($uploadedImg3) $img3 = $uploadedImg3;
        $uploadedVid = uploadCatalogFile('video_file', 'products');
        if ($uploadedVid) $videoUrl = $uploadedVid;

        if (empty($productCode)) {
            $productCode = 'TG' . rand(100, 999) . 'A' . str_pad($advertiserId, 3, '0', STR_PAD_LEFT) . 'P' . rand(10, 99);
        }

        try {
            if ($productId > 0) {
                // UPDATE
                $stmt = $pdo->prepare("
                    UPDATE products SET 
                        product_code = ?, category = ?, category_en = ?, category_hi = ?, advertiser_id = ?, 
                        product_name = ?, product_name_en = ?, product_name_hi = ?,
                        price = ?, mrp = ?, in_stock = ?, is_active = ?, region_id = ?,
                        product_description = ?, product_description_en = ?, product_description_hi = ?,
                        image_url_1 = ?, image_url_2 = ?, image_url_3 = ?, product_video_url = ?
                    WHERE product_id = ?
                ");
                $stmt->execute([
                    $productCode, $category, $categoryEn, $categoryHi, $advertiserId,
                    $nameTe, $nameEn, $nameHi,
                    $price, $mrp, $inStock, $isActive, $regionId,
                    $descTe, $descEn, $descHi,
                    $img1, $img2, $img3, $videoUrl,
                    $productId
                ]);
                setFlash("Product #{$productId} updated successfully.");
            } else {
                // INSERT
                $stmt = $pdo->prepare("
                    INSERT INTO products (
                        product_code, category, category_en, category_hi, advertiser_id,
                        product_name, product_name_en, product_name_hi,
                        price, mrp, in_stock, is_active, region_id,
                        product_description, product_description_en, product_description_hi,
                        image_url_1, image_url_2, image_url_3, product_video_url, created_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
                ");
                $stmt->execute([
                    $productCode, $category, $categoryEn, $categoryHi, $advertiserId,
                    $nameTe, $nameEn, $nameHi,
                    $price, $mrp, $inStock, $isActive, $regionId,
                    $descTe, $descEn, $descHi,
                    $img1, $img2, $img3, $videoUrl
                ]);
                setFlash("New product '{$nameEn}' listed successfully.");
            }
        } catch (Throwable $e) {
            setFlash("Database Error: " . $e->getMessage(), 'danger');
        }
        header("Location: ?tab=products");
        exit();
    }

    if ($action === 'delete_product') {
        $pid = intval($_POST['product_id'] ?? 0);
        if ($pid > 0) {
            try {
                $pdo->prepare("DELETE FROM enquiries WHERE product_id = ?")->execute([$pid]);
                $pdo->prepare("DELETE FROM products WHERE product_id = ?")->execute([$pid]);
                setFlash("Product deleted successfully.");
            } catch (Throwable $e) {
                setFlash("Error deleting product: " . $e->getMessage(), 'danger');
            }
        }
        header("Location: ?tab=products");
        exit();
    }

    if ($action === 'bulk_products_action') {
        $ids = $_POST['selected_products'] ?? [];
        $bulkType = $_POST['bulk_type'] ?? '';
        if (!empty($ids) && is_array($ids)) {
            $cleanIds = array_filter(array_map('intval', $ids));
            if (!empty($cleanIds)) {
                $ph = implode(',', array_fill(0, count($cleanIds), '?'));
                try {
                    if ($bulkType === 'activate') {
                        $pdo->prepare("UPDATE products SET is_active = 1 WHERE product_id IN ($ph)")->execute($cleanIds);
                        setFlash(count($cleanIds) . " products marked visible.");
                    } elseif ($bulkType === 'deactivate') {
                        $pdo->prepare("UPDATE products SET is_active = 0 WHERE product_id IN ($ph)")->execute($cleanIds);
                        setFlash(count($cleanIds) . " products hidden.");
                    } elseif ($bulkType === 'in_stock') {
                        $pdo->prepare("UPDATE products SET in_stock = 1 WHERE product_id IN ($ph)")->execute($cleanIds);
                        setFlash(count($cleanIds) . " products marked In Stock.");
                    } elseif ($bulkType === 'out_stock') {
                        $pdo->prepare("UPDATE products SET in_stock = 0 WHERE product_id IN ($ph)")->execute($cleanIds);
                        setFlash(count($cleanIds) . " products marked Out of Stock.");
                    } elseif ($bulkType === 'delete') {
                        $pdo->prepare("DELETE FROM enquiries WHERE product_id IN ($ph)")->execute($cleanIds);
                        $pdo->prepare("DELETE FROM products WHERE product_id IN ($ph)")->execute($cleanIds);
                        setFlash(count($cleanIds) . " products deleted.");
                    }
                } catch (Throwable $e) {
                    setFlash("Bulk action failed: " . $e->getMessage(), 'danger');
                }
            }
        }
        header("Location: ?tab=products");
        exit();
    }

    // ==========================================
    // B. SEED VARIETIES CRUD
    // ==========================================
    if ($action === 'save_variety') {
        $varietyId = intval($_POST['variety_id'] ?? 0);
        $cropName = trim($_POST['crop_name'] ?? 'Rice');
        $nameTe = trim($_POST['variety_name_te'] ?? '');
        $nameEn = trim($_POST['variety_name_en'] ?? '');
        $nameHi = trim($_POST['variety_name_hi'] ?? '');
        if (empty($nameTe)) $nameTe = $nameEn;
        if (empty($nameEn)) $nameEn = $nameTe;

        $detailsTe = trim($_POST['details_te'] ?? '');
        $detailsEn = trim($_POST['details_en'] ?? '');
        $detailsHi = trim($_POST['details_hi'] ?? '');

        $regionEn = trim($_POST['region_en'] ?? '');
        $regionTe = trim($_POST['region_te'] ?? '');
        $regionHi = trim($_POST['region_hi'] ?? '');
        $sowingPeriodEn = trim($_POST['sowing_period_en'] ?? '');
        $sowingPeriodTe = trim($_POST['sowing_period_te'] ?? '');
        $sowingPeriodHi = trim($_POST['sowing_period_hi'] ?? '');

        $region = trim($_POST['region'] ?? '');
        if (empty($region)) {
            $region = !empty($regionTe) ? $regionTe : (!empty($regionEn) ? $regionEn : $regionHi);
        }
        if (empty($regionTe) && !empty($region)) {
            $regionTe = $region;
        }
        if (empty($regionEn) && !empty($region) && preg_match('/^[A-Za-z0-9 ,.\/-]+$/', $region)) {
            $regionEn = $region;
        }

        $sowingPeriod = trim($_POST['sowing_period'] ?? '');
        if (empty($sowingPeriod)) {
            $sowingPeriod = !empty($sowingPeriodTe) ? $sowingPeriodTe : (!empty($sowingPeriodEn) ? $sowingPeriodEn : $sowingPeriodHi);
        }
        if (empty($sowingPeriodTe) && !empty($sowingPeriod)) {
            $sowingPeriodTe = $sowingPeriod;
        }
        if (empty($sowingPeriodEn) && !empty($sowingPeriod) && preg_match('/^[A-Za-z0-9 ,.\/-]+$/', $sowingPeriod)) {
            $sowingPeriodEn = $sowingPeriod;
        }

        $avgYield = !empty($_POST['average_yield']) ? floatval($_POST['average_yield']) : null;
        $growthDuration = !empty($_POST['growth_duration']) ? intval($_POST['growth_duration']) : null;
        $imageUrl = trim($_POST['image_url'] ?? '');
        $videoUrl = trim($_POST['testimonial_video_url'] ?? '');

        $uploadedImg = uploadCatalogFile('variety_image_file', 'seed-images');
        if ($uploadedImg) $imageUrl = $uploadedImg;
        $uploadedVid = uploadCatalogFile('variety_video_file', 'videos');
        if ($uploadedVid) $videoUrl = $uploadedVid;

        // Vendor Listing data
        $vendorId = intval($_POST['vendor_id'] ?? 1);
        $basePrice = floatval($_POST['base_price'] ?? 0);
        $packetSize = trim($_POST['packet_size'] ?? 'per_kg');
        $stockQty = intval($_POST['stock_quantity'] ?? 100);
        $isAllRegions = isset($_POST['is_all_regions']) ? 1 : 0;
        $listingActive = isset($_POST['listing_active']) ? 1 : 1;

        try {
            if ($varietyId > 0) {
                // UPDATE variety
                $stmt = $pdo->prepare("
                    UPDATE seed_varieties SET 
                        crop_name = ?, variety_name_te = ?, variety_name_en = ?, variety_name_hi = ?,
                        image_url = ?, details_te = ?, details_en = ?, details_hi = ?,
                        region = ?, region_en = ?, region_te = ?, region_hi = ?,
                        sowing_period = ?, sowing_period_en = ?, sowing_period_te = ?, sowing_period_hi = ?,
                        testimonial_video_url = ?,
                        average_yield = ?, growth_duration = ?
                    WHERE id = ?
                ");
                $stmt->execute([
                    $cropName, $nameTe, $nameEn, $nameHi,
                    $imageUrl, $detailsTe, $detailsEn, $detailsHi,
                    $region, $regionEn, $regionTe, $regionHi,
                    $sowingPeriod, $sowingPeriodEn, $sowingPeriodTe, $sowingPeriodHi,
                    $videoUrl,
                    $avgYield, $growthDuration,
                    $varietyId
                ]);

                // Update or Insert vendor listing
                $chkListing = $pdo->prepare("SELECT id FROM vendor_listings WHERE seed_variety_id = ? LIMIT 1");
                $chkListing->execute([$varietyId]);
                $existingListing = $chkListing->fetch();
                if ($existingListing) {
                    $pdo->prepare("
                        UPDATE vendor_listings SET 
                            vendor_id = ?, packet_size = ?, base_price = ?, stock_quantity = ?, 
                            is_all_regions = ?, is_active = ?
                        WHERE id = ?
                    ")->execute([
                        $vendorId, $packetSize, $basePrice, $stockQty, $isAllRegions, $listingActive, $existingListing['id']
                    ]);
                } else {
                    $pdo->prepare("
                        INSERT INTO vendor_listings (
                            vendor_id, seed_variety_id, packet_size, base_price, stock_quantity, is_all_regions, is_active
                        ) VALUES (?, ?, ?, ?, ?, ?, ?)
                    ")->execute([
                        $vendorId, $varietyId, $packetSize, $basePrice, $stockQty, $isAllRegions, $listingActive
                    ]);
                }

                setFlash("Seed variety '{$nameEn}' updated successfully.");
            } else {
                // INSERT variety
                $stmt = $pdo->prepare("
                    INSERT INTO seed_varieties (
                        crop_name, variety_name_te, variety_name_en, variety_name_hi,
                        image_url, details_te, details_en, details_hi,
                        region, region_en, region_te, region_hi,
                        sowing_period, sowing_period_en, sowing_period_te, sowing_period_hi,
                        testimonial_video_url, average_yield, growth_duration, created_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
                ");
                $stmt->execute([
                    $cropName, $nameTe, $nameEn, $nameHi,
                    $imageUrl, $detailsTe, $detailsEn, $detailsHi,
                    $region, $regionEn, $regionTe, $regionHi,
                    $sowingPeriod, $sowingPeriodEn, $sowingPeriodTe, $sowingPeriodHi,
                    $videoUrl,
                    $avgYield, $growthDuration
                ]);
                $newVarietyId = $pdo->lastInsertId();

                // Create vendor listing
                $pdo->prepare("
                    INSERT INTO vendor_listings (
                        vendor_id, seed_variety_id, packet_size, base_price, stock_quantity, is_all_regions, is_active
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)
                ")->execute([
                    $vendorId, $newVarietyId, $packetSize, $basePrice, $stockQty, $isAllRegions, $listingActive
                ]);

                setFlash("New seed variety '{$nameEn}' added successfully.");
            }
        } catch (Throwable $e) {
            setFlash("Error saving variety: " . $e->getMessage(), 'danger');
        }
        header("Location: ?tab=varieties");
        exit();
    }

    if ($action === 'delete_variety') {
        $vid = intval($_POST['variety_id'] ?? 0);
        if ($vid > 0) {
            try {
                $pdo->beginTransaction();

                // 1. Find all listing IDs for this seed variety
                $lStmt = $pdo->prepare("SELECT id FROM vendor_listings WHERE seed_variety_id = ?");
                $lStmt->execute([$vid]);
                $listingIds = $lStmt->fetchAll(PDO::FETCH_COLUMN);

                // 2. Delete all child bookings first to satisfy foreign key constraints (fk_booking_listing)
                if (!empty($listingIds)) {
                    $ph = implode(',', array_fill(0, count($listingIds), '?'));
                    $delBookings = $pdo->prepare("DELETE FROM bookings WHERE seed_variety_id = ? OR listing_id IN ($ph)");
                    $delBookings->execute(array_merge([$vid], $listingIds));
                } else {
                    $pdo->prepare("DELETE FROM bookings WHERE seed_variety_id = ?")->execute([$vid]);
                }

                // 3. Delete vendor listings
                $pdo->prepare("DELETE FROM vendor_listings WHERE seed_variety_id = ?")->execute([$vid]);

                // 4. Delete the seed variety itself
                $pdo->prepare("DELETE FROM seed_varieties WHERE id = ?")->execute([$vid]);

                $pdo->commit();
                setFlash("Seed variety and associated bookings deleted successfully.");
            } catch (Throwable $e) {
                if ($pdo->inTransaction()) {
                    $pdo->rollBack();
                }
                setFlash("Error deleting variety: " . $e->getMessage(), 'danger');
            }
        }
        header("Location: ?tab=varieties");
        exit();
    }

    // ==========================================
    // C. MULTILINGUAL CATEGORIES & CROPS CRUD
    // ==========================================
    if ($action === 'save_category') {
        $catId = intval($_POST['category_id'] ?? 0);
        $nameEn = trim($_POST['category_name_en'] ?? '');
        $nameTe = trim($_POST['category_name_te'] ?? '');
        $nameHi = trim($_POST['category_name_hi'] ?? '');
        $oldTe = trim($_POST['old_category_name_te'] ?? '');
        $oldEn = trim($_POST['old_category_name_en'] ?? '');

        if (empty($nameEn)) $nameEn = $nameTe;
        if (empty($nameTe)) $nameTe = $nameEn;

        // Ensure category column can accept any new text
        try {
            $pdo->exec("ALTER TABLE `products` MODIFY COLUMN `category` VARCHAR(100) NOT NULL DEFAULT 'General'");
        } catch (Throwable $e) {}

        try {
            if ($catId > 0) {
                $pdo->prepare("
                    UPDATE `product_categories` SET 
                        category_name_en = ?, category_name_te = ?, category_name_hi = ?
                    WHERE id = ?
                ")->execute([$nameEn, $nameTe, $nameHi, $catId]);

                // Synchronize all products assigned to this category across all 3 languages
                $targets = array_unique(array_filter([$oldTe, $oldEn, $nameTe, $nameEn]));
                if (!empty($targets)) {
                    $inPlaceholders = implode(',', array_fill(0, count($targets), '?'));
                    $syncStmt = $pdo->prepare("
                        UPDATE products 
                        SET category = ?, category_en = ?, category_hi = ? 
                        WHERE category IN ($inPlaceholders) OR category_en IN ($inPlaceholders)
                    ");
                    $syncParams = array_merge([$nameTe, $nameEn, $nameHi], $targets, $targets);
                    $syncStmt->execute($syncParams);
                }
                setFlash("Category '{$nameEn}' updated across all 3 languages and synchronized with products table.");
            } else {
                $pdo->prepare("
                    INSERT INTO `product_categories` (category_name_en, category_name_te, category_name_hi) 
                    VALUES (?, ?, ?)
                ")->execute([$nameEn, $nameTe, $nameHi]);
                setFlash("New category '{$nameEn}' created successfully.");
            }
        } catch (Throwable $e) {
            setFlash("Error saving category: " . $e->getMessage(), 'danger');
        }
        header("Location: ?tab=categories");
        exit();
    }

    if ($action === 'sync_categories_products') {
        try {
            $pdo->exec("ALTER TABLE `products` MODIFY COLUMN `category` VARCHAR(100) NOT NULL DEFAULT 'General'");
            
            // Sync products having matching categories
            $pdo->exec("
                UPDATE `products` p
                JOIN `product_categories` pc ON (p.category = pc.category_name_te OR p.category = pc.category_name_en OR p.category_en = pc.category_name_en)
                SET p.category = pc.category_name_te,
                    p.category_en = pc.category_name_en,
                    p.category_hi = IFNULL(pc.category_name_hi, p.category_hi)
            ");
            setFlash("All products synchronized with master product categories.");
        } catch (Throwable $e) {
            setFlash("Sync failed: " . $e->getMessage(), 'danger');
        }
        header("Location: ?tab=categories");
        exit();
    }

    if ($action === 'delete_category') {
        $catId = intval($_POST['category_id'] ?? 0);
        if ($catId > 0) {
            try {
                $pdo->prepare("DELETE FROM `product_categories` WHERE id = ?")->execute([$catId]);
                setFlash("Category deleted from master list.");
            } catch (Throwable $e) {
                setFlash("Error deleting category: " . $e->getMessage(), 'danger');
            }
        }
        header("Location: ?tab=categories");
        exit();
    }

    if ($action === 'save_crop') {
        $cropId = intval($_POST['crop_id'] ?? 0);
        $nameTe = trim($_POST['name'] ?? '');
        $nameEn = trim($_POST['name_en'] ?? '');
        $nameHi = trim($_POST['name_hi'] ?? '');
        $imageUrl = trim($_POST['image_url'] ?? '');

        $uploadedCropImg = uploadCatalogFile('crop_image_file', 'crops');
        if ($uploadedCropImg) $imageUrl = $uploadedCropImg;

        try {
            if ($cropId > 0) {
                $pdo->prepare("UPDATE crops SET name = ?, name_en = ?, name_hi = ?, image_url = ? WHERE id = ?")
                    ->execute([$nameTe, $nameEn, $nameHi, $imageUrl, $cropId]);
                setFlash("Crop #{$cropId} updated.");
            } else {
                $pdo->prepare("INSERT INTO crops (name, name_en, name_hi, image_url) VALUES (?, ?, ?, ?)")
                    ->execute([$nameTe, $nameEn, $nameHi, $imageUrl]);
                setFlash("New crop '{$nameEn}' added.");
            }
        } catch (Throwable $e) {
            setFlash("Error saving crop: " . $e->getMessage(), 'danger');
        }
        header("Location: ?tab=categories");
        exit();
    }

    if ($action === 'delete_crop') {
        $cropId = intval($_POST['crop_id'] ?? 0);
        if ($cropId > 0) {
            try {
                $pdo->prepare("DELETE FROM crops WHERE id = ?")->execute([$cropId]);
                setFlash("Crop deleted.");
            } catch (Throwable $e) {
                setFlash("Error deleting crop: " . $e->getMessage(), 'danger');
            }
        }
        header("Location: ?tab=categories");
        exit();
    }

    // ==========================================
    // D. ADVERTISERS & VENDORS
    // ==========================================
    if ($action === 'save_advertiser') {
        $advName = trim($_POST['advertiser_name'] ?? '');
        $email = trim($_POST['email_address'] ?? '');
        $advCode = trim($_POST['advertiser_code'] ?? ('TG01A' . rand(100, 999)));
        $password = trim($_POST['password'] ?? '12345678');

        if (!empty($advName)) {
            try {
                $pdo->prepare("
                    INSERT INTO advertisers (advertiser_code, advertiser_name, email_address, password_hash)
                    VALUES (?, ?, ?, ?)
                ")->execute([$advCode, $advName, $email, $password]);
                setFlash("Advertiser '{$advName}' added.");
            } catch (Throwable $e) {
                setFlash("Error adding advertiser: " . $e->getMessage(), 'danger');
            }
        }
        header("Location: ?tab=uploaders");
        exit();
    }

    if ($action === 'save_vendor') {
        $compName = trim($_POST['company_name'] ?? '');
        $contact = trim($_POST['contact_number'] ?? '');
        $license = trim($_POST['license_number'] ?? '');
        $logo = trim($_POST['logo_url'] ?? '');

        if (!empty($compName)) {
            try {
                $pdo->prepare("
                    INSERT INTO vendors (company_name, license_number, contact_number, is_verified, logo_url, password)
                    VALUES (?, ?, ?, 1, ?, '12345678')
                ")->execute([$compName, $license, $contact, $logo]);
                setFlash("Seed vendor '{$compName}' added.");
            } catch (Throwable $e) {
                setFlash("Error adding vendor: " . $e->getMessage(), 'danger');
            }
        }
        header("Location: ?tab=uploaders");
        exit();
    }

    // ==========================================
    // E. LEADS & BOOKINGS STATUS
    // ==========================================
    if ($action === 'update_enquiry_status') {
        $enqId = intval($_POST['enquiry_id'] ?? 0);
        $status = trim($_POST['status'] ?? 'Interested');
        if ($enqId > 0) {
            $pdo->prepare("UPDATE enquiries SET status = ? WHERE enquiry_id = ?")->execute([$status, $enqId]);
            setFlash("Enquiry status updated.");
        }
        header("Location: ?tab=leads");
        exit();
    }

    if ($action === 'update_booking_status') {
        $bkId = trim($_POST['booking_id'] ?? '');
        $status = trim($_POST['booking_status'] ?? 'pending');
        if (!empty($bkId)) {
            $pdo->prepare("UPDATE bookings SET booking_status = ? WHERE booking_id = ?")->execute([$status, $bkId]);
            setFlash("Booking status updated.");
        }
        header("Location: ?tab=leads");
        exit();
    }
}

// -------------------------------------------------------------
// 6. Data Querying for Display
// -------------------------------------------------------------
$activeTab = $_GET['tab'] ?? 'products';
$flash = getFlash();

// Search & Filter inputs
$q = trim($_GET['q'] ?? '');
$filterCategory = trim($_GET['cat'] ?? 'all');
$filterAdvertiser = intval($_GET['adv'] ?? 0);
$filterCrop = trim($_GET['crop'] ?? 'all');
$filterStock = trim($_GET['stock'] ?? 'all');
$filterActive = trim($_GET['active'] ?? 'all');

// Global Stats
$stats = [
    'total_products' => 0,
    'active_products' => 0,
    'out_of_stock' => 0,
    'total_varieties' => 0,
    'total_crops' => 0,
    'total_categories' => 0,
    'total_advertisers' => 0,
    'total_vendors' => 0,
    'total_enquiries' => 0,
    'total_bookings' => 0,
];

$advertisers = [];
$vendors = [];
$regions = [];
$productCategories = [];
$cropsList = [];
$productsList = [];
$varietiesList = [];
$enquiriesList = [];
$bookingsList = [];

if (isset($pdo) && $pdo instanceof PDO) {
    try {
        // Base lookups
        $advertisers = $pdo->query("SELECT * FROM advertisers ORDER BY advertiser_name ASC")->fetchAll();
        $vendors = $pdo->query("SELECT * FROM vendors ORDER BY company_name ASC")->fetchAll();
        $regions = $pdo->query("SELECT * FROM regions ORDER BY region_name ASC")->fetchAll();
        $cropsList = $pdo->query("SELECT c.*, (SELECT COUNT(*) FROM seed_varieties sv WHERE sv.crop_name = c.name_en OR sv.crop_name = c.name) as varieties_count FROM crops c ORDER BY c.id ASC")->fetchAll();

        // Multilingual product categories with live product counts
        $productCategories = $pdo->query("
            SELECT pc.*, 
                   (SELECT COUNT(*) FROM products p WHERE p.category = pc.category_name_te OR p.category = pc.category_name_en OR p.category_en = pc.category_name_en) as count 
            FROM product_categories pc 
            ORDER BY count DESC, pc.category_name_en ASC
        ")->fetchAll();

        // Metrics
        $stats['total_products'] = intval($pdo->query("SELECT COUNT(*) FROM products")->fetchColumn());
        $stats['active_products'] = intval($pdo->query("SELECT COUNT(*) FROM products WHERE is_active = 1")->fetchColumn());
        $stats['out_of_stock'] = intval($pdo->query("SELECT COUNT(*) FROM products WHERE in_stock = 0")->fetchColumn());
        $stats['total_varieties'] = intval($pdo->query("SELECT COUNT(*) FROM seed_varieties")->fetchColumn());
        $stats['total_crops'] = count($cropsList);
        $stats['total_categories'] = count($productCategories);
        $stats['total_advertisers'] = count($advertisers);
        $stats['total_vendors'] = count($vendors);
        $stats['total_enquiries'] = intval($pdo->query("SELECT COUNT(*) FROM enquiries")->fetchColumn());
        $stats['total_bookings'] = intval($pdo->query("SELECT COUNT(*) FROM bookings")->fetchColumn());

        // Products Tab Query (Irrespective of uploader)
        if ($activeTab === 'products') {
            $pSql = "
                SELECT p.*, a.advertiser_name, r.region_name,
                       (SELECT COUNT(*) FROM enquiries e WHERE e.product_id = p.product_id) as enquiries_count
                FROM products p
                LEFT JOIN advertisers a ON p.advertiser_id = a.advertiser_id
                LEFT JOIN regions r ON p.region_id = r.id
                WHERE 1=1
            ";
            $pParams = [];

            if (!empty($q)) {
                $pSql .= " AND (p.product_name LIKE ? OR p.product_name_en LIKE ? OR p.product_code LIKE ? OR p.product_description LIKE ?)";
                $like = "%$q%";
                $pParams = array_merge($pParams, [$like, $like, $like, $like]);
            }
            if ($filterCategory !== 'all' && !empty($filterCategory)) {
                $pSql .= " AND (p.category = ? OR p.category_en = ?)";
                $pParams[] = $filterCategory;
                $pParams[] = $filterCategory;
            }
            if ($filterAdvertiser > 0) {
                $pSql .= " AND p.advertiser_id = ?";
                $pParams[] = $filterAdvertiser;
            }
            if ($filterStock === 'in') {
                $pSql .= " AND p.in_stock = 1";
            } elseif ($filterStock === 'out') {
                $pSql .= " AND p.in_stock = 0";
            }
            if ($filterActive === 'yes') {
                $pSql .= " AND p.is_active = 1";
            } elseif ($filterActive === 'no') {
                $pSql .= " AND p.is_active = 0";
            }

            $pSql .= " ORDER BY p.product_id DESC LIMIT 200";
            $stmt = $pdo->prepare($pSql);
            $stmt->execute($pParams);
            $productsList = $stmt->fetchAll();
        }

        // Seed Varieties Tab Query
        if ($activeTab === 'varieties') {
            $vSql = "
                SELECT sv.*, 
                       vl.id as listing_id, vl.vendor_id, vl.packet_size, vl.base_price, vl.stock_quantity, 
                       vl.is_all_regions, vl.is_active as listing_active,
                       v.company_name as vendor_name,
                       (SELECT COUNT(*) FROM bookings b WHERE b.seed_variety_id = sv.id) as bookings_count
                FROM seed_varieties sv
                LEFT JOIN vendor_listings vl ON sv.id = vl.seed_variety_id
                LEFT JOIN vendors v ON vl.vendor_id = v.id
                WHERE 1=1
            ";
            $vParams = [];

            if (!empty($q)) {
                $vSql .= " AND (sv.variety_name_en LIKE ? OR sv.variety_name_te LIKE ? OR sv.variety_name_hi LIKE ? OR sv.details_en LIKE ? OR sv.region LIKE ? OR sv.region_en LIKE ? OR sv.region_te LIKE ? OR sv.region_hi LIKE ? OR sv.sowing_period LIKE ? OR sv.sowing_period_en LIKE ? OR sv.sowing_period_te LIKE ?)";
                $like = "%$q%";
                $vParams = array_merge($vParams, array_fill(0, 11, $like));
            }
            if ($filterCrop !== 'all' && !empty($filterCrop)) {
                $vSql .= " AND sv.crop_name = ?";
                $vParams[] = $filterCrop;
            }

            $vSql .= " ORDER BY sv.id DESC LIMIT 200";
            $stmt = $pdo->prepare($vSql);
            $stmt->execute($vParams);
            $varietiesList = $stmt->fetchAll();
        }

        // Leads & Bookings Tab Query (Fix: ORDER BY booking_timestamp DESC instead of non-existent b.id)
        if ($activeTab === 'leads') {
            $enquiriesList = $pdo->query("
                SELECT e.*, p.product_name, p.product_name_en, a.advertiser_name, u.name as farmer_name, u.phone_number as farmer_phone
                FROM enquiries e
                LEFT JOIN products p ON e.product_id = p.product_id
                LEFT JOIN advertisers a ON e.advertiser_id = a.advertiser_id
                LEFT JOIN users u ON (e.farmer_id = u.user_id OR e.farmer_id = u.phone_number)
                ORDER BY e.enquiry_id DESC LIMIT 100
            ")->fetchAll();

            $bookingsList = $pdo->query("
                SELECT b.*, sv.variety_name_en, sv.variety_name_te, sv.crop_name, u.name as farmer_name, u.phone_number as farmer_phone, vl.packet_size
                FROM bookings b
                LEFT JOIN seed_varieties sv ON b.seed_variety_id = sv.id
                LEFT JOIN vendor_listings vl ON b.listing_id = vl.id
                LEFT JOIN users u ON (b.user_id = u.user_id OR b.user_id = u.phone_number)
                ORDER BY b.booking_timestamp DESC LIMIT 100
            ")->fetchAll();
        }

    } catch (Throwable $e) {
        $dbError = $e->getMessage();
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CropSync Catalog Central - Agri Shop & Seeds Management</title>
    
    <!-- Google Sans & Noto Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Google+Sans:ital,wght@0,400;0,500;0,600;0,700;1,400&family=Noto+Sans+Telugu:wght@400;500;600;700&family=Noto+Sans+Devanagari:wght@400;500;600&display=swap" rel="stylesheet">
    
    <!-- Phosphor Icons -->
    <script src="https://unpkg.com/@phosphor-icons/web@2.1.1"></script>

    <!-- Alpine.js -->
    <script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.14.3/dist/cdn.min.js"></script>

    <style>
        [x-cloak] { display: none !important; }

        :root {
            --font-family: 'Google Sans', 'Noto Sans Telugu', 'Noto Sans Devanagari', -apple-system, BlinkMacSystemFont, sans-serif;
            --bg: #f8fafc;
            --surface: #ffffff;
            --surface-subtle: #f1f5f9;
            --surface-hover: #f8fafc;
            --border: #e2e8f0;
            --border-light: #edf2f7;

            --text-primary: #0f172a;
            --text-secondary: #475569;
            --text-muted: #94a3b8;

            --primary: #16a34a;
            --primary-dark: #15803d;
            --primary-light: #f0fdf4;
            --primary-ring: rgba(22, 163, 74, 0.2);

            --accent: #2563eb;
            --accent-light: #eff6ff;

            --amber: #d97706;
            --amber-light: #fef3c7;

            --danger: #dc2626;
            --danger-light: #fef2f2;

            --radius: 8px;
            --radius-pill: 9999px;
            --shadow-sm: 0 1px 2px 0 rgb(0 0 0 / 0.05);
            --shadow-md: 0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1);
            --header-height: 60px;
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            font-family: var(--font-family);
            background: var(--bg);
            color: var(--text-primary);
            line-height: 1.5;
            -webkit-font-smoothing: antialiased;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
        }

        /* HEADER */
        header.app-header {
            background: var(--surface);
            border-bottom: 1px solid var(--border);
            height: var(--header-height);
            padding: 0 28px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            position: sticky;
            top: 0;
            z-index: 40;
            box-shadow: var(--shadow-sm);
        }

        .header-brand {
            display: flex;
            align-items: center;
            gap: 14px;
            text-decoration: none;
            color: var(--text-primary);
        }

        .brand-icon {
            width: 36px;
            height: 36px;
            background: linear-gradient(135deg, #16a34a, #059669);
            color: white;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 1.25rem;
            box-shadow: 0 2px 4px rgba(22, 163, 74, 0.25);
        }

        .brand-text h1 {
            font-size: 1.05rem;
            font-weight: 700;
            letter-spacing: -0.02em;
            color: var(--text-primary);
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .brand-badge {
            font-size: 0.7rem;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.04em;
            background: var(--primary-light);
            color: var(--primary-dark);
            padding: 2px 8px;
            border-radius: var(--radius-pill);
            border: 1px solid rgba(22, 163, 74, 0.2);
        }

        .header-actions {
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .btn-header {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 7px 14px;
            font-size: 0.84rem;
            font-weight: 600;
            border-radius: var(--radius);
            text-decoration: none;
            transition: all 0.15s ease;
            cursor: pointer;
            border: 1px solid var(--border);
            background: var(--surface);
            color: var(--text-secondary);
        }

        .btn-header:hover {
            background: var(--surface-subtle);
            color: var(--text-primary);
        }

        /* KPI / STATS BAR */
        .kpi-section {
            padding: 20px 28px 8px 28px;
            background: var(--surface);
            border-bottom: 1px solid var(--border);
        }

        .kpi-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
            gap: 16px;
        }

        .kpi-card {
            background: var(--bg);
            border: 1px solid var(--border);
            border-radius: var(--radius);
            padding: 14px 18px;
            display: flex;
            flex-direction: column;
            gap: 4px;
            transition: transform 0.15s ease;
        }

        .kpi-card:hover {
            border-color: #cbd5e1;
            transform: translateY(-1px);
        }

        .kpi-title {
            font-size: 0.75rem;
            font-weight: 600;
            color: var(--text-muted);
            text-transform: uppercase;
            letter-spacing: 0.03em;
            display: flex;
            align-items: center;
            gap: 6px;
        }

        .kpi-value {
            font-size: 1.45rem;
            font-weight: 700;
            color: var(--text-primary);
            letter-spacing: -0.02em;
        }

        .kpi-sub {
            font-size: 0.75rem;
            color: var(--text-secondary);
        }

        /* NAVIGATION TABS */
        .nav-tabs-bar {
            background: var(--surface);
            border-bottom: 1px solid var(--border);
            padding: 0 28px;
            display: flex;
            gap: 24px;
            overflow-x: auto;
        }

        .tab-link {
            padding: 14px 2px;
            font-size: 0.9rem;
            font-weight: 500;
            color: var(--text-secondary);
            text-decoration: none;
            border-bottom: 2px solid transparent;
            display: inline-flex;
            align-items: center;
            gap: 8px;
            white-space: nowrap;
            transition: all 0.15s ease;
        }

        .tab-link:hover { color: var(--text-primary); }

        .tab-link.active {
            color: var(--primary-dark);
            font-weight: 700;
            border-bottom-color: var(--primary);
        }

        .tab-counter {
            font-size: 0.72rem;
            font-weight: 700;
            background: var(--surface-subtle);
            color: var(--text-secondary);
            padding: 2px 7px;
            border-radius: var(--radius-pill);
            border: 1px solid var(--border);
        }

        .tab-link.active .tab-counter {
            background: var(--primary-light);
            color: var(--primary-dark);
            border-color: rgba(22, 163, 74, 0.2);
        }

        /* MAIN CONTENT AREA */
        main.main-content {
            flex: 1;
            padding: 24px 28px 60px 28px;
            max-width: 1600px;
            width: 100%;
            margin: 0 auto;
        }

        /* FLASH ALERT */
        .flash-alert {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 12px 18px;
            border-radius: var(--radius);
            font-size: 0.88rem;
            margin-bottom: 20px;
        }

        .flash-alert.success {
            background: var(--primary-light);
            color: var(--primary-dark);
            border: 1px solid rgba(22, 163, 74, 0.3);
        }

        .flash-alert.danger {
            background: var(--danger-light);
            color: var(--danger);
            border: 1px solid rgba(220, 38, 38, 0.3);
        }

        /* TOOLBAR / CONTROLS */
        .controls-toolbar {
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: var(--radius);
            padding: 14px 18px;
            margin-bottom: 20px;
            display: flex;
            flex-wrap: wrap;
            align-items: center;
            justify-content: space-between;
            gap: 14px;
            box-shadow: var(--shadow-sm);
        }

        .filter-group {
            display: flex;
            align-items: center;
            flex-wrap: wrap;
            gap: 10px;
        }

        .search-box {
            position: relative;
            min-width: 250px;
        }

        .search-box i {
            position: absolute;
            left: 12px;
            top: 50%;
            transform: translateY(-50%);
            color: var(--text-muted);
            font-size: 1rem;
        }

        .search-box input {
            width: 100%;
            padding: 8px 12px 8px 36px;
            border: 1px solid var(--border);
            border-radius: var(--radius);
            font-family: inherit;
            font-size: 0.86rem;
            background: var(--surface);
            color: var(--text-primary);
            outline: none;
            transition: border-color 0.15s;
        }

        .search-box input:focus {
            border-color: var(--primary);
            box-shadow: 0 0 0 3px var(--primary-ring);
        }

        /* ============================================================== */
        /* ALPINE.JS CUSTOM DROPDOWN COMPONENT STYLES (ZERO NATIVE SELECT) */
        /* ============================================================== */
        .alpine-select-wrapper {
            position: relative;
            display: inline-block;
        }

        .alpine-select-wrapper.full-width {
            width: 100%;
        }

        .alpine-select-trigger {
            padding: 8px 12px;
            border: 1px solid var(--border);
            border-radius: var(--radius);
            font-family: inherit;
            font-size: 0.86rem;
            background: var(--surface);
            color: var(--text-primary);
            cursor: pointer;
            display: inline-flex;
            align-items: center;
            justify-content: space-between;
            gap: 8px;
            min-width: 150px;
            user-select: none;
            transition: border-color 0.15s, box-shadow 0.15s;
        }

        .alpine-select-wrapper.full-width .alpine-select-trigger {
            width: 100%;
        }

        .alpine-select-trigger:hover {
            border-color: #94a3b8;
        }

        .alpine-select-trigger.active {
            border-color: var(--primary);
            box-shadow: 0 0 0 3px var(--primary-ring);
        }

        .alpine-select-trigger i.ph-caret-down {
            font-size: 0.85rem;
            color: var(--text-muted);
            transition: transform 0.2s ease;
        }

        .alpine-select-trigger.active i.ph-caret-down {
            transform: rotate(180deg);
        }

        .alpine-select-menu {
            position: absolute;
            top: calc(100% + 4px);
            left: 0;
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: var(--radius);
            box-shadow: var(--shadow-md);
            z-index: 120;
            min-width: 100%;
            max-height: 250px;
            overflow-y: auto;
            padding: 4px;
            animation: dropdownFade 0.15s ease-out;
        }

        .alpine-select-menu.right-align {
            left: auto;
            right: 0;
        }

        @keyframes dropdownFade {
            from { opacity: 0; transform: translateY(-4px); }
            to { opacity: 1; transform: translateY(0); }
        }

        .alpine-select-option {
            padding: 7px 10px;
            font-size: 0.84rem;
            color: var(--text-secondary);
            border-radius: 5px;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 10px;
            transition: background 0.1s ease;
            white-space: nowrap;
        }

        .alpine-select-option:hover {
            background: var(--surface-subtle);
            color: var(--text-primary);
        }

        .alpine-select-option.selected {
            background: var(--primary-light);
            color: var(--primary-dark);
            font-weight: 600;
        }

        .alpine-select-option i.check-icon {
            font-size: 0.85rem;
            color: var(--primary-dark);
        }

        /* BUTTONS */
        .btn {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            gap: 6px;
            padding: 8px 16px;
            font-size: 0.86rem;
            font-weight: 600;
            border-radius: var(--radius);
            cursor: pointer;
            text-decoration: none;
            transition: all 0.15s ease;
            border: 1px solid transparent;
            font-family: inherit;
        }

        .btn-primary { background: var(--primary); color: white; }
        .btn-primary:hover { background: var(--primary-dark); }
        .btn-secondary { background: var(--surface); border-color: var(--border); color: var(--text-secondary); }
        .btn-secondary:hover { background: var(--surface-subtle); color: var(--text-primary); }
        .btn-danger-outline { background: transparent; border-color: #fca5a5; color: var(--danger); }
        .btn-danger-outline:hover { background: var(--danger-light); }
        .btn-xs { padding: 4px 8px; font-size: 0.75rem; border-radius: 6px; }

        /* DATA TABLE CONTAINER */
        .table-card {
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: var(--radius);
            box-shadow: var(--shadow-sm);
            overflow: hidden;
        }

        .table-responsive {
            width: 100%;
            overflow-x: auto;
        }

        table.data-table {
            width: 100%;
            border-collapse: collapse;
            text-align: left;
            font-size: 0.86rem;
        }

        table.data-table thead tr {
            background: var(--surface-subtle);
            border-bottom: 1px solid var(--border);
        }

        table.data-table th {
            padding: 12px 16px;
            font-weight: 600;
            color: var(--text-secondary);
            font-size: 0.76rem;
            text-transform: uppercase;
            letter-spacing: 0.03em;
            white-space: nowrap;
        }

        table.data-table td {
            padding: 12px 16px;
            border-bottom: 1px solid var(--border-light);
            color: var(--text-primary);
            vertical-align: middle;
        }

        table.data-table tbody tr:hover { background: var(--surface-hover); }
        table.data-table tbody tr:last-child td { border-bottom: none; }

        /* BADGES & PILLS */
        .badge {
            display: inline-flex;
            align-items: center;
            gap: 4px;
            padding: 3px 8px;
            font-size: 0.72rem;
            font-weight: 600;
            border-radius: var(--radius-pill);
            white-space: nowrap;
        }

        .badge-green { background: #dcfce7; color: #15803d; border: 1px solid #bbf7d0; }
        .badge-red { background: #fee2e2; color: #b91c1c; border: 1px solid #fecaca; }
        .badge-blue { background: #dbeafe; color: #1d4ed8; border: 1px solid #bfdbfe; }
        .badge-amber { background: #fef3c7; color: #b45309; border: 1px solid #fde68a; }
        .badge-gray { background: #f1f5f9; color: #475569; border: 1px solid #e2e8f0; }

        .uploader-pill {
            display: inline-flex;
            align-items: center;
            gap: 5px;
            padding: 2px 8px;
            font-size: 0.74rem;
            font-weight: 500;
            color: #334155;
            background: #f1f5f9;
            border: 1px solid #cbd5e1;
            border-radius: 6px;
        }

        /* THUMBNAILS */
        .media-thumb {
            width: 44px;
            height: 44px;
            border-radius: 6px;
            object-fit: cover;
            border: 1px solid var(--border);
            background: var(--surface-subtle);
            display: block;
        }

        .media-thumb-placeholder {
            width: 44px;
            height: 44px;
            border-radius: 6px;
            border: 1px solid var(--border);
            background: var(--surface-subtle);
            display: flex;
            align-items: center;
            justify-content: center;
            color: var(--text-muted);
            font-size: 1.2rem;
        }

        /* TOGGLE SWITCH */
        .switch {
            position: relative;
            display: inline-block;
            width: 36px;
            height: 20px;
        }

        .switch input { opacity: 0; width: 0; height: 0; }

        .slider {
            position: absolute;
            cursor: pointer;
            top: 0; left: 0; right: 0; bottom: 0;
            background-color: #cbd5e1;
            transition: .2s;
            border-radius: 20px;
        }

        .slider:before {
            position: absolute;
            content: "";
            height: 14px;
            width: 14px;
            left: 3px;
            bottom: 3px;
            background-color: white;
            transition: .2s;
            border-radius: 50%;
        }

        input:checked + .slider { background-color: var(--primary); }
        input:checked + .slider:before { transform: translateX(16px); }

        /* MODALS */
        .modal-overlay {
            position: fixed;
            inset: 0;
            background: rgba(15, 23, 42, 0.6);
            backdrop-filter: blur(3px);
            z-index: 100;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
            overflow-y: auto;
        }

        .modal-container {
            background: var(--surface);
            border-radius: 12px;
            width: 100%;
            max-width: 780px;
            max-height: 90vh;
            display: flex;
            flex-direction: column;
            box-shadow: 0 20px 25px -5px rgb(0 0 0 / 0.1);
            animation: modalSlide 0.2s ease-out;
            overflow: hidden;
            margin: auto;
        }

        .modal-container form {
            display: flex;
            flex-direction: column;
            flex: 1 1 auto;
            min-height: 0;
            overflow: hidden;
        }

        @keyframes modalSlide {
            from { opacity: 0; transform: scale(0.97); }
            to { opacity: 1; transform: scale(1); }
        }

        .modal-header {
            padding: 16px 24px;
            border-bottom: 1px solid var(--border);
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-shrink: 0;
        }

        .modal-header h3 {
            font-size: 1.1rem;
            font-weight: 700;
            color: var(--text-primary);
        }

        .modal-body {
            padding: 24px;
            overflow-y: auto;
            -webkit-overflow-scrolling: touch;
            display: flex;
            flex-direction: column;
            gap: 16px;
            flex: 1 1 auto;
            min-height: 0;
        }

        .modal-body::-webkit-scrollbar {
            width: 7px;
        }

        .modal-body::-webkit-scrollbar-track {
            background: #f1f5f9;
            border-radius: 4px;
        }

        .modal-body::-webkit-scrollbar-thumb {
            background: #cbd5e1;
            border-radius: 4px;
        }

        .modal-body::-webkit-scrollbar-thumb:hover {
            background: #94a3b8;
        }

        .modal-footer {
            padding: 16px 24px;
            border-top: 1px solid var(--border);
            background: var(--surface-subtle);
            display: flex;
            align-items: center;
            justify-content: flex-end;
            gap: 10px;
            flex-shrink: 0;
        }

        /* FORM GROUPS */
        .form-grid {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 16px;
        }

        .form-group {
            display: flex;
            flex-direction: column;
            gap: 6px;
        }

        .form-group.full {
            grid-column: span 2;
        }

        .form-label {
            font-size: 0.8rem;
            font-weight: 600;
            color: var(--text-secondary);
            display: flex;
            align-items: center;
            justify-content: space-between;
        }

        .form-input, .form-textarea {
            padding: 9px 12px;
            border: 1px solid var(--border);
            border-radius: var(--radius);
            font-family: inherit;
            font-size: 0.86rem;
            color: var(--text-primary);
            background: var(--surface);
            outline: none;
            transition: border-color 0.15s;
        }

        .form-input:focus, .form-textarea:focus {
            border-color: var(--primary);
            box-shadow: 0 0 0 3px var(--primary-ring);
        }

        .form-textarea {
            resize: vertical;
            min-height: 80px;
        }

        .helper-text {
            font-size: 0.73rem;
            color: var(--text-muted);
        }

        .btn-translate {
            background: var(--accent-light);
            color: var(--accent);
            border: 1px solid rgba(37, 99, 235, 0.2);
            font-size: 0.72rem;
            font-weight: 600;
            padding: 3px 9px;
            border-radius: 4px;
            cursor: pointer;
            display: inline-flex;
            align-items: center;
            gap: 5px;
            transition: all 0.15s;
        }

        .btn-translate:hover {
            background: #dbeafe;
        }

        /* EMPTY STATE */
        .empty-state {
            padding: 48px 24px;
            text-align: center;
            color: var(--text-muted);
        }

        .empty-state i {
            font-size: 3rem;
            margin-bottom: 12px;
            color: #cbd5e1;
        }

        .empty-state p {
            font-size: 0.95rem;
            color: var(--text-secondary);
            margin-bottom: 16px;
        }

        /* CUSTOM MEDIA UPLOADER WITH PROGRESS INDICATOR */
        .media-upload-card {
            background: var(--surface-subtle);
            border: 1px dashed var(--border);
            border-radius: var(--radius);
            padding: 8px 10px;
            transition: border-color 0.2s, background-color 0.2s;
            position: relative;
        }

        .media-upload-card.dragover {
            border-color: var(--primary);
            background: #eff6ff;
        }

        .media-input-row {
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .media-preview-thumb {
            width: 42px;
            height: 42px;
            border-radius: 6px;
            position: relative;
            flex-shrink: 0;
            border: 1px solid var(--border);
            overflow: hidden;
            background: #ffffff;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .media-preview-thumb img {
            width: 100%;
            height: 100%;
            object-fit: cover;
        }

        .media-preview-thumb.video-preview {
            background: #0f172a;
            color: #38bdf8;
            font-size: 1.3rem;
        }

        .media-preview-placeholder {
            width: 42px;
            height: 42px;
            border-radius: 6px;
            flex-shrink: 0;
            border: 1px solid var(--border);
            background: #f8fafc;
            color: var(--text-muted);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 1.25rem;
        }

        .media-clear-btn {
            position: absolute;
            top: 2px;
            right: 2px;
            background: rgba(0, 0, 0, 0.7);
            color: #ffffff;
            border: none;
            border-radius: 50%;
            width: 16px;
            height: 16px;
            font-size: 12px;
            line-height: 1;
            display: flex;
            align-items: center;
            justify-content: center;
            cursor: pointer;
            padding: 0;
            transition: background 0.15s;
        }

        .media-clear-btn:hover {
            background: #dc2626;
        }

        .media-url-input {
            flex: 1;
            font-size: 0.84rem;
            padding: 7px 10px;
            background: #ffffff;
        }

        .btn-upload {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 7px 12px;
            font-size: 0.8rem;
            font-weight: 600;
            white-space: nowrap;
            background: #ffffff;
            border: 1px solid var(--border);
            color: var(--text-primary);
            border-radius: var(--radius);
            cursor: pointer;
            transition: all 0.15s;
        }

        .btn-upload:hover:not(:disabled) {
            background: #f1f5f9;
            border-color: #94a3b8;
            color: var(--primary);
        }

        .btn-upload:disabled {
            opacity: 0.7;
            cursor: not-allowed;
        }

        .media-progress-bar-wrap {
            margin-top: 6px;
            background: #e2e8f0;
            border-radius: 9999px;
            height: 5px;
            overflow: hidden;
            position: relative;
        }

        .media-progress-bar-fill {
            height: 100%;
            width: 0%;
            background: linear-gradient(90deg, #16a34a, #22c55e);
            transition: width 0.15s ease;
        }

        .media-status-text {
            font-size: 0.73rem;
            margin-top: 4px;
            font-weight: 500;
        }

        .media-status-text.info { color: #0284c7; }
        .media-status-text.success { color: #15803d; }
        .media-status-text.error { color: #b91c1c; }

        .spin {
            animation: spinAnimation 1s linear infinite;
        }

        @keyframes spinAnimation {
            from { transform: rotate(0deg); }
            to { transform: rotate(360deg); }
        }

        /* ============================================================== */
        /* PRODUCTION-GRADE CUSTOM CONFIRM MODAL & TOAST STACK */
        /* ============================================================== */
        .btn-danger { background: var(--danger); color: white; border-color: transparent; }
        .btn-danger:hover { background: #b91c1c; }

        /* Floating Toast Stack */
        .toast-stack-container {
            position: fixed;
            top: 24px;
            right: 24px;
            z-index: 100000;
            display: flex;
            flex-direction: column;
            gap: 10px;
            max-width: 420px;
            width: calc(100vw - 48px);
            pointer-events: none;
        }

        .toast-item {
            pointer-events: auto;
            display: flex;
            align-items: flex-start;
            gap: 12px;
            padding: 14px 16px;
            background: #ffffff;
            border-radius: 10px;
            box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.1), 0 8px 10px -6px rgba(0, 0, 0, 0.1);
            border: 1px solid var(--border);
            animation: toastSlideIn 0.25s cubic-bezier(0.16, 1, 0.3, 1);
            transition: all 0.2s ease;
        }

        @keyframes toastSlideIn {
            from { transform: translateX(100%); opacity: 0; }
            to { transform: translateX(0); opacity: 1; }
        }

        .toast-icon {
            font-size: 1.25rem;
            flex-shrink: 0;
            margin-top: 1px;
        }

        .toast-content {
            flex: 1;
            font-size: 0.88rem;
            font-weight: 500;
            line-height: 1.45;
            color: var(--text-primary);
            word-break: break-word;
        }

        .toast-close {
            background: none;
            border: none;
            color: var(--text-muted);
            cursor: pointer;
            font-size: 1.1rem;
            line-height: 1;
            padding: 2px;
            margin-top: -2px;
            transition: color 0.15s;
        }

        .toast-close:hover {
            color: var(--text-primary);
        }

        .toast-item.toast-success {
            border-left: 4px solid var(--primary);
        }
        .toast-item.toast-success .toast-icon {
            color: var(--primary);
        }

        .toast-item.toast-danger, .toast-item.toast-error {
            border-left: 4px solid var(--danger);
        }
        .toast-item.toast-danger .toast-icon, .toast-item.toast-error .toast-icon {
            color: var(--danger);
        }

        .toast-item.toast-warning {
            border-left: 4px solid var(--amber);
        }
        .toast-item.toast-warning .toast-icon {
            color: var(--amber);
        }

        .toast-item.toast-info {
            border-left: 4px solid var(--accent);
        }
        .toast-item.toast-info .toast-icon {
            color: var(--accent);
        }

        /* Custom Confirmation Modal */
        .confirm-modal-backdrop {
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(15, 23, 42, 0.6);
            backdrop-filter: blur(4px);
            z-index: 99999;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
            animation: fadeIn 0.2s ease;
        }

        .confirm-modal-card {
            background: #ffffff;
            border-radius: 16px;
            width: 100%;
            max-width: 440px;
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
            border: 1px solid var(--border);
            padding: 24px;
            display: flex;
            flex-direction: column;
            align-items: center;
            text-align: center;
            animation: popIn 0.22s cubic-bezier(0.16, 1, 0.3, 1);
        }

        @keyframes popIn {
            from { transform: scale(0.92); opacity: 0; }
            to { transform: scale(1); opacity: 1; }
        }

        .confirm-icon-bubble {
            width: 54px;
            height: 54px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 1.6rem;
            margin-bottom: 16px;
        }

        .confirm-icon-bubble.confirm-danger {
            background: #fee2e2;
            color: #dc2626;
        }

        .confirm-icon-bubble.confirm-warning {
            background: #fef3c7;
            color: #d97706;
        }

        .confirm-icon-bubble.confirm-info {
            background: #e0f2fe;
            color: #0284c7;
        }

        .confirm-icon-bubble.confirm-success {
            background: #dcfce7;
            color: #16a34a;
        }

        .confirm-card-title {
            font-size: 1.15rem;
            font-weight: 700;
            color: var(--text-primary);
            margin-bottom: 8px;
        }

        .confirm-card-message {
            font-size: 0.92rem;
            color: var(--text-secondary);
            line-height: 1.5;
            margin-bottom: 6px;
            word-break: break-word;
        }

        .confirm-card-subtext {
            font-size: 0.78rem;
            color: var(--text-muted);
            margin-bottom: 20px;
        }

        .confirm-modal-actions {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 12px;
            width: 100%;
            margin-top: 14px;
        }

        .confirm-modal-actions .btn {
            flex: 1;
            padding: 10px 16px;
            font-size: 0.9rem;
        }
    </style>
</head>
<body x-data="catalogApp()" x-init="init()">

    <!-- Floating Toast Notifications (Stack) -->
    <div class="toast-stack-container" aria-live="polite">
        <template x-for="toast in toasts" :key="toast.id">
            <div class="toast-item" :class="'toast-' + toast.type">
                <div class="toast-icon">
                    <i class="ph-bold" :class="toast.type === 'success' ? 'ph-check-circle' : (toast.type === 'danger' || toast.type === 'error' ? 'ph-warning-circle' : (toast.type === 'warning' ? 'ph-warning' : 'ph-info'))"></i>
                </div>
                <div class="toast-content" x-text="toast.message"></div>
                <button type="button" class="toast-close" @click="removeToast(toast.id)" title="Close">&times;</button>
            </div>
        </template>
    </div>

    <!-- Custom Confirmation Modal (Zero Browser Popups) -->
    <div class="confirm-modal-backdrop" x-show="confirmModal.show" x-cloak @keydown.escape.window="closeConfirm()">
        <div class="confirm-modal-card" @click.outside="closeConfirm()">
            <div class="confirm-icon-bubble" :class="'confirm-' + confirmModal.iconColor">
                <i class="ph-bold" :class="confirmModal.icon"></i>
            </div>
            <div class="confirm-card-content">
                <h4 class="confirm-card-title" x-text="confirmModal.title"></h4>
                <p class="confirm-card-message" x-text="confirmModal.message"></p>
                <p class="confirm-card-subtext" x-show="confirmModal.subtext" x-text="confirmModal.subtext"></p>
            </div>
            <div class="confirm-modal-actions">
                <button type="button" class="btn btn-secondary" @click="closeConfirm()" :disabled="confirmModal.loading">
                    Cancel
                </button>
                <button type="button" class="btn" :class="confirmModal.confirmClass" @click="executeConfirm()" :disabled="confirmModal.loading">
                    <i class="ph-bold ph-spinner-gap spin" x-show="confirmModal.loading"></i>
                    <span x-text="confirmModal.confirmText"></span>
                </button>
            </div>
        </div>
    </div>

    <!-- 1. APP HEADER -->
    <header class="app-header">
        <a href="?tab=products" class="header-brand">
            <div class="brand-icon">
                <i class="ph-bold ph-storefront"></i>
            </div>
            <div class="brand-text">
                <h1>
                    CropSync Catalog Central
                    <span class="brand-badge">Master Manager</span>
                </h1>
            </div>
        </a>

        <div class="header-actions">
            <!-- Studio Dashboard Link -->
            <a href="dashboard.php" class="btn-header" title="Go to News & Agri Reels Studio">
                <i class="ph-bold ph-film-strip"></i>
                News & Reels Studio
            </a>

            <!-- Fake Farmers (Hyderabad) Dashboard Link -->
            <a href="fake_farmers_dashboard.php" class="btn-header" title="Manage Fake Farmers (Hyderabad)">
                <i class="ph-bold ph-users-three"></i>
                Fake Farmers (Hyd)
            </a>

            <!-- Quick Refresh -->
            <a href="javascript:location.reload()" class="btn-header" title="Refresh Data">
                <i class="ph ph-arrows-clockwise"></i>
            </a>
        </div>
    </header>

    <!-- 2. KPI / OVERVIEW BAR -->
    <section class="kpi-section">
        <div class="kpi-grid">
            <div class="kpi-card">
                <div class="kpi-title"><i class="ph-bold ph-package text-emerald-600"></i> Agri Shop Products</div>
                <div class="kpi-value"><?= number_format($stats['total_products']) ?></div>
                <div class="kpi-sub">
                    <span class="text-emerald-600 font-semibold"><?= $stats['active_products'] ?> active</span> &bull; 
                    <span class="text-amber-600"><?= $stats['out_of_stock'] ?> out of stock</span>
                </div>
            </div>

            <div class="kpi-card">
                <div class="kpi-title"><i class="ph-bold ph-plant text-green-600"></i> Seed Varieties</div>
                <div class="kpi-value"><?= number_format($stats['total_varieties']) ?></div>
                <div class="kpi-sub">Across <?= $stats['total_crops'] ?> agricultural crops</div>
            </div>

            <div class="kpi-card">
                <div class="kpi-title"><i class="ph-bold ph-squares-four text-blue-600"></i> Categories & Crops</div>
                <div class="kpi-value"><?= $stats['total_categories'] ?> / <?= $stats['total_crops'] ?></div>
                <div class="kpi-sub">Shop categories & Master crops</div>
            </div>

            <div class="kpi-card">
                <div class="kpi-title"><i class="ph-bold ph-buildings text-indigo-600"></i> Sellers & Vendors</div>
                <div class="kpi-value"><?= $stats['total_advertisers'] + $stats['total_vendors'] ?></div>
                <div class="kpi-sub"><?= $stats['total_advertisers'] ?> advertisers &bull; <?= $stats['total_vendors'] ?> seed vendors</div>
            </div>

            <div class="kpi-card">
                <div class="kpi-title"><i class="ph-bold ph-chats-circle text-purple-600"></i> Customer Demand</div>
                <div class="kpi-value"><?= number_format($stats['total_enquiries'] + $stats['total_bookings']) ?></div>
                <div class="kpi-sub"><?= $stats['total_enquiries'] ?> enquiries &bull; <?= $stats['total_bookings'] ?> seed bookings</div>
            </div>
        </div>
    </section>

    <!-- 3. NAVIGATION TABS BAR -->
    <nav class="nav-tabs-bar">
        <a href="?tab=products" class="tab-link <?= $activeTab === 'products' ? 'active' : '' ?>">
            <i class="ph-bold ph-package"></i> Agri Shop Products
            <span class="tab-counter"><?= $stats['total_products'] ?></span>
        </a>
        <a href="?tab=varieties" class="tab-link <?= $activeTab === 'varieties' ? 'active' : '' ?>">
            <i class="ph-bold ph-plant"></i> Seed Varieties
            <span class="tab-counter"><?= $stats['total_varieties'] ?></span>
        </a>
        <a href="?tab=categories" class="tab-link <?= $activeTab === 'categories' ? 'active' : '' ?>">
            <i class="ph-bold ph-squares-four"></i> Categories & Crops Master
            <span class="tab-counter"><?= $stats['total_categories'] ?></span>
        </a>
        <a href="?tab=uploaders" class="tab-link <?= $activeTab === 'uploaders' ? 'active' : '' ?>">
            <i class="ph-bold ph-users-three"></i> Vendors & Advertisers
            <span class="tab-counter"><?= $stats['total_advertisers'] + $stats['total_vendors'] ?></span>
        </a>
        <a href="?tab=leads" class="tab-link <?= $activeTab === 'leads' ? 'active' : '' ?>">
            <i class="ph-bold ph-chart-line-up"></i> Enquiries & Bookings
            <span class="tab-counter"><?= $stats['total_enquiries'] + $stats['total_bookings'] ?></span>
        </a>
    </nav>

    <!-- 4. MAIN CONTENT CONTAINER -->
    <main class="main-content">

        <!-- Flash Message Notification -->
        <?php if ($flash): ?>
            <div class="flash-alert <?= htmlspecialchars($flash['type']) ?>">
                <span><?= htmlspecialchars($flash['text']) ?></span>
                <button type="button" onclick="this.parentElement.remove()" style="background:none;border:none;cursor:pointer;font-size:1.1rem;">&times;</button>
            </div>
        <?php endif; ?>

        <!-- ============================================================== -->
        <!-- TAB 1: AGRI SHOP PRODUCTS -->
        <!-- ============================================================== -->
        <?php if ($activeTab === 'products'): ?>
            
            <div class="controls-toolbar">
                <form method="GET" id="productsFilterForm" class="filter-group">
                    <input type="hidden" name="tab" value="products">

                    <!-- Search Input -->
                    <div class="search-box">
                        <i class="ph ph-magnifying-glass"></i>
                        <input type="text" name="q" value="<?= htmlspecialchars($q) ?>" placeholder="Search product name, code...">
                    </div>

                    <!-- 100% Alpine.js Advertiser Filter -->
                    <?php 
                        $curAdvName = 'All Advertisers';
                        foreach ($advertisers as $adv) {
                            if ($filterAdvertiser == $adv['advertiser_id']) {
                                $curAdvName = $adv['advertiser_name'];
                                break;
                            }
                        }
                    ?>
                    <div class="alpine-select-wrapper" x-data="{ open: false, label: '<?= htmlspecialchars(addslashes($curAdvName)) ?>', val: <?= $filterAdvertiser ?> }" @click.outside="open = false">
                        <input type="hidden" name="adv" :value="val">
                        <div class="alpine-select-trigger" :class="{ 'active': open }" @click="open = !open">
                            <span x-text="label"></span>
                            <i class="ph ph-caret-down"></i>
                        </div>
                        <div class="alpine-select-menu" x-show="open" x-cloak x-transition>
                            <div class="alpine-select-option" :class="{ 'selected': val == 0 }" @click="label = 'All Advertisers'; val = 0; open = false; $nextTick(() => document.getElementById('productsFilterForm').submit())">
                                <span>All Advertisers (<?= count($advertisers) ?>)</span>
                                <i class="ph-bold ph-check check-icon" x-show="val == 0"></i>
                            </div>
                            <?php foreach ($advertisers as $adv): ?>
                                <div class="alpine-select-option" :class="{ 'selected': val == <?= $adv['advertiser_id'] ?> }" @click="label = '<?= htmlspecialchars(addslashes($adv['advertiser_name'])) ?>'; val = <?= $adv['advertiser_id'] ?>; open = false; $nextTick(() => document.getElementById('productsFilterForm').submit())">
                                    <span><?= htmlspecialchars($adv['advertiser_name']) ?></span>
                                    <i class="ph-bold ph-check check-icon" x-show="val == <?= $adv['advertiser_id'] ?>"></i>
                                </div>
                            <?php endforeach; ?>
                        </div>
                    </div>

                    <!-- 100% Alpine.js Category Filter -->
                    <?php 
                        $curCatName = 'All Categories';
                        foreach ($productCategories as $catRow) {
                            if ($filterCategory === $catRow['category_name_en'] || $filterCategory === $catRow['category_name_te']) {
                                $curCatName = $catRow['category_name_en'] . ' (' . $catRow['category_name_te'] . ')';
                                break;
                            }
                        }
                    ?>
                    <div class="alpine-select-wrapper" x-data="{ open: false, label: '<?= htmlspecialchars(addslashes($curCatName)) ?>', val: '<?= htmlspecialchars(addslashes($filterCategory)) ?>' }" @click.outside="open = false">
                        <input type="hidden" name="cat" :value="val">
                        <div class="alpine-select-trigger" :class="{ 'active': open }" @click="open = !open">
                            <span x-text="label"></span>
                            <i class="ph ph-caret-down"></i>
                        </div>
                        <div class="alpine-select-menu" x-show="open" x-cloak x-transition>
                            <div class="alpine-select-option" :class="{ 'selected': val === 'all' }" @click="label = 'All Categories'; val = 'all'; open = false; $nextTick(() => document.getElementById('productsFilterForm').submit())">
                                <span>All Categories</span>
                                <i class="ph-bold ph-check check-icon" x-show="val === 'all'"></i>
                            </div>
                            <?php foreach ($productCategories as $catRow): ?>
                                <div class="alpine-select-option" :class="{ 'selected': val === '<?= htmlspecialchars(addslashes($catRow['category_name_en'])) ?>' }" @click="label = '<?= htmlspecialchars(addslashes($catRow['category_name_en'] . ' (' . $catRow['category_name_te'] . ')')) ?>'; val = '<?= htmlspecialchars(addslashes($catRow['category_name_en'])) ?>'; open = false; $nextTick(() => document.getElementById('productsFilterForm').submit())">
                                    <span><?= htmlspecialchars($catRow['category_name_en']) ?> (<?= htmlspecialchars($catRow['category_name_te']) ?>) &bull; <?= $catRow['count'] ?></span>
                                    <i class="ph-bold ph-check check-icon" x-show="val === '<?= htmlspecialchars(addslashes($catRow['category_name_en'])) ?>'"></i>
                                </div>
                            <?php endforeach; ?>
                        </div>
                    </div>

                    <!-- 100% Alpine.js Stock Filter -->
                    <?php 
                        $stockLabels = ['all' => 'All Stock Status', 'in' => 'In Stock Only', 'out' => 'Out of Stock'];
                        $curStockLabel = $stockLabels[$filterStock] ?? 'All Stock Status';
                    ?>
                    <div class="alpine-select-wrapper" x-data="{ open: false, label: '<?= $curStockLabel ?>', val: '<?= $filterStock ?>' }" @click.outside="open = false">
                        <input type="hidden" name="stock" :value="val">
                        <div class="alpine-select-trigger" :class="{ 'active': open }" @click="open = !open">
                            <span x-text="label"></span>
                            <i class="ph ph-caret-down"></i>
                        </div>
                        <div class="alpine-select-menu" x-show="open" x-cloak x-transition>
                            <div class="alpine-select-option" :class="{ 'selected': val === 'all' }" @click="label = 'All Stock Status'; val = 'all'; open = false; $nextTick(() => document.getElementById('productsFilterForm').submit())">
                                <span>All Stock Status</span>
                                <i class="ph-bold ph-check check-icon" x-show="val === 'all'"></i>
                            </div>
                            <div class="alpine-select-option" :class="{ 'selected': val === 'in' }" @click="label = 'In Stock Only'; val = 'in'; open = false; $nextTick(() => document.getElementById('productsFilterForm').submit())">
                                <span>In Stock Only</span>
                                <i class="ph-bold ph-check check-icon" x-show="val === 'in'"></i>
                            </div>
                            <div class="alpine-select-option" :class="{ 'selected': val === 'out' }" @click="label = 'Out of Stock'; val = 'out'; open = false; $nextTick(() => document.getElementById('productsFilterForm').submit())">
                                <span>Out of Stock</span>
                                <i class="ph-bold ph-check check-icon" x-show="val === 'out'"></i>
                            </div>
                        </div>
                    </div>

                    <!-- 100% Alpine.js Visibility Filter -->
                    <?php 
                        $activeLabels = ['all' => 'All Visibility', 'yes' => 'Active / Visible', 'no' => 'Hidden'];
                        $curActiveLabel = $activeLabels[$filterActive] ?? 'All Visibility';
                    ?>
                    <div class="alpine-select-wrapper" x-data="{ open: false, label: '<?= $curActiveLabel ?>', val: '<?= $filterActive ?>' }" @click.outside="open = false">
                        <input type="hidden" name="active" :value="val">
                        <div class="alpine-select-trigger" :class="{ 'active': open }" @click="open = !open">
                            <span x-text="label"></span>
                            <i class="ph ph-caret-down"></i>
                        </div>
                        <div class="alpine-select-menu" x-show="open" x-cloak x-transition>
                            <div class="alpine-select-option" :class="{ 'selected': val === 'all' }" @click="label = 'All Visibility'; val = 'all'; open = false; $nextTick(() => document.getElementById('productsFilterForm').submit())">
                                <span>All Visibility</span>
                                <i class="ph-bold ph-check check-icon" x-show="val === 'all'"></i>
                            </div>
                            <div class="alpine-select-option" :class="{ 'selected': val === 'yes' }" @click="label = 'Active / Visible'; val = 'yes'; open = false; $nextTick(() => document.getElementById('productsFilterForm').submit())">
                                <span>Active / Visible</span>
                                <i class="ph-bold ph-check check-icon" x-show="val === 'yes'"></i>
                            </div>
                            <div class="alpine-select-option" :class="{ 'selected': val === 'no' }" @click="label = 'Hidden'; val = 'no'; open = false; $nextTick(() => document.getElementById('productsFilterForm').submit())">
                                <span>Hidden</span>
                                <i class="ph-bold ph-check check-icon" x-show="val === 'no'"></i>
                            </div>
                        </div>
                    </div>

                    <button type="submit" class="btn btn-secondary btn-xs">Apply</button>
                    <?php if (!empty($q) || $filterCategory !== 'all' || $filterAdvertiser > 0 || $filterStock !== 'all' || $filterActive !== 'all'): ?>
                        <a href="?tab=products" class="btn btn-secondary btn-xs">Reset</a>
                    <?php endif; ?>
                </form>

                <div class="action-buttons">
                    <button type="button" @click="openProductModal()" class="btn btn-primary">
                        <i class="ph-bold ph-plus"></i> Add New Product
                    </button>
                </div>
            </div>

            <!-- Products Table Card -->
            <form method="POST" id="bulkProductsForm">
                <input type="hidden" name="action" value="bulk_products_action">
                
                <div class="table-card">
                    <div class="table-responsive">
                        <table class="data-table">
                            <thead>
                                <tr>
                                    <th style="width: 30px;"><input type="checkbox" @change="toggleSelectAll($event, 'selected_products[]')"></th>
                                    <th>Image</th>
                                    <th>Product Details</th>
                                    <th>Category (EN / TE)</th>
                                    <th>Advertiser / Uploader</th>
                                    <th>Price / MRP</th>
                                    <th>In Stock</th>
                                    <th>Visible</th>
                                    <th style="text-align: right;">Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php if (empty($productsList)): ?>
                                    <tr>
                                        <td colspan="9">
                                            <div class="empty-state">
                                                <i class="ph ph-package"></i>
                                                <p>No products found matching the criteria.</p>
                                                <button type="button" @click="openProductModal()" class="btn btn-primary">
                                                    <i class="ph-bold ph-plus"></i> Add First Product
                                                </button>
                                            </div>
                                        </td>
                                    </tr>
                                <?php else: ?>
                                    <?php foreach ($productsList as $prod): ?>
                                        <tr>
                                            <td>
                                                <input type="checkbox" name="selected_products[]" value="<?= $prod['product_id'] ?>">
                                            </td>
                                            <td>
                                                <?php if (!empty($prod['image_url_1'])): ?>
                                                    <img src="<?= htmlspecialchars($prod['image_url_1']) ?>" alt="" class="media-thumb" loading="lazy">
                                                <?php else: ?>
                                                    <div class="media-thumb-placeholder">
                                                        <i class="ph ph-package"></i>
                                                    </div>
                                                <?php endif; ?>
                                            </td>
                                            <td>
                                                <div style="font-weight: 600; color: var(--text-primary);">
                                                    <?= htmlspecialchars($prod['product_name_en'] ?: $prod['product_name']) ?>
                                                </div>
                                                <?php if (!empty($prod['product_name']) && $prod['product_name'] !== $prod['product_name_en']): ?>
                                                    <div style="font-size: 0.78rem; color: var(--text-secondary);">
                                                        <?= htmlspecialchars($prod['product_name']) ?>
                                                    </div>
                                                <?php endif; ?>
                                                <div style="font-size: 0.72rem; color: var(--text-muted); display: flex; gap: 8px; margin-top: 2px;">
                                                    <span>Code: <?= htmlspecialchars($prod['product_code'] ?? 'N/A') ?></span>
                                                    <span>&bull;</span>
                                                    <span>ID: #<?= $prod['product_id'] ?></span>
                                                    <?php if ($prod['enquiries_count'] > 0): ?>
                                                        <span>&bull;</span>
                                                        <span style="color: var(--accent); font-weight:600;"><?= $prod['enquiries_count'] ?> enquiries</span>
                                                    <?php endif; ?>
                                                </div>
                                            </td>
                                            <td>
                                                <div style="font-weight: 600; font-size: 0.82rem;">
                                                    <?= htmlspecialchars($prod['category_en'] ?: $prod['category']) ?>
                                                </div>
                                                <?php if (!empty($prod['category']) && $prod['category'] !== $prod['category_en']): ?>
                                                    <div style="font-size: 0.74rem; color: var(--text-secondary);">
                                                        <?= htmlspecialchars($prod['category']) ?>
                                                    </div>
                                                <?php endif; ?>
                                            </td>
                                            <td>
                                                <div class="uploader-pill" title="Original Uploader / Company">
                                                    <i class="ph-fill ph-storefront text-slate-500"></i>
                                                    <?= htmlspecialchars($prod['advertiser_name'] ?? 'Advertiser #' . $prod['advertiser_id']) ?>
                                                </div>
                                            </td>
                                            <td>
                                                <div style="font-weight: 700; color: var(--text-primary);">
                                                    ₹<?= number_format($prod['price'], 2) ?>
                                                </div>
                                                <?php if (!empty($prod['mrp']) && $prod['mrp'] > $prod['price']): ?>
                                                    <div style="font-size: 0.72rem; color: var(--text-muted); text-decoration: line-through;">
                                                        MRP ₹<?= number_format($prod['mrp'], 2) ?>
                                                    </div>
                                                <?php endif; ?>
                                            </td>
                                            <td>
                                                <label class="switch" title="Toggle Stock">
                                                    <input type="checkbox" <?= $prod['in_stock'] ? 'checked' : '' ?> @change="toggleProductStock(<?= $prod['product_id'] ?>, $event.target.checked)">
                                                    <span class="slider"></span>
                                                </label>
                                            </td>
                                            <td>
                                                <label class="switch" title="Toggle Visibility">
                                                    <input type="checkbox" <?= $prod['is_active'] ? 'checked' : '' ?> @change="toggleProductActive(<?= $prod['product_id'] ?>, $event.target.checked)">
                                                    <span class="slider"></span>
                                                </label>
                                            </td>
                                            <td style="text-align: right; white-space: nowrap;">
                                                <button type="button" @click="editProduct(<?= htmlspecialchars(json_encode($prod)) ?>)" class="btn btn-secondary btn-xs" title="Edit Product">
                                                    <i class="ph-bold ph-pencil-simple"></i> Edit
                                                </button>
                                                <button type="button" @click="confirmDeleteProduct(<?= $prod['product_id'] ?>, '<?= htmlspecialchars(addslashes($prod['product_name_en'] ?: $prod['product_name'])) ?>')" class="btn btn-danger-outline btn-xs" title="Delete">
                                                    <i class="ph-bold ph-trash"></i>
                                                </button>
                                            </td>
                                        </tr>
                                    <?php endforeach; ?>
                                <?php endif; ?>
                            </tbody>
                        </table>
                    </div>

                    <!-- Bulk Actions Bar with Alpine Dropdown -->
                    <?php if (!empty($productsList)): ?>
                        <div style="padding: 12px 18px; border-top: 1px solid var(--border); display: flex; align-items: center; justify-content: space-between; background: var(--surface-subtle);">
                            <div style="font-size: 0.8rem; color: var(--text-muted);">
                                Showing <?= count($productsList) ?> products
                            </div>
                            <div style="display: flex; align-items: center; gap: 8px;">
                                <div class="alpine-select-wrapper" x-data="{ open: false, label: 'Mark Visible', val: 'activate' }" @click.outside="open = false">
                                    <input type="hidden" name="bulk_type" :value="val">
                                    <div class="alpine-select-trigger" style="min-width: 130px; padding: 5px 10px; font-size: 0.8rem;" :class="{ 'active': open }" @click="open = !open">
                                        <span x-text="label"></span>
                                        <i class="ph ph-caret-down"></i>
                                    </div>
                                    <div class="alpine-select-menu" style="bottom: calc(100% + 4px); top: auto;" x-show="open" x-cloak x-transition>
                                        <div class="alpine-select-option" @click="label = 'Mark Visible'; val = 'activate'; open = false;">Mark Visible</div>
                                        <div class="alpine-select-option" @click="label = 'Hide from App'; val = 'deactivate'; open = false;">Hide from App</div>
                                        <div class="alpine-select-option" @click="label = 'Mark In Stock'; val = 'in_stock'; open = false;">Mark In Stock</div>
                                        <div class="alpine-select-option" @click="label = 'Mark Out of Stock'; val = 'out_stock'; open = false;">Mark Out of Stock</div>
                                        <div class="alpine-select-option" @click="label = 'Delete Selected'; val = 'delete'; open = false;">Delete Selected</div>
                                    </div>
                                </div>
                                <button type="button" @click="confirmBulkProducts()" class="btn btn-secondary btn-xs">Apply</button>
                            </div>
                        </div>
                    <?php endif; ?>
                </div>
            </form>

        <?php endif; ?>

        <!-- ============================================================== -->
        <!-- TAB 2: SEED VARIETIES -->
        <!-- ============================================================== -->
        <?php if ($activeTab === 'varieties'): ?>

            <div class="controls-toolbar">
                <form method="GET" id="varietiesFilterForm" class="filter-group">
                    <input type="hidden" name="tab" value="varieties">

                    <!-- Search Input -->
                    <div class="search-box">
                        <i class="ph ph-magnifying-glass"></i>
                        <input type="text" name="q" value="<?= htmlspecialchars($q) ?>" placeholder="Search variety name, region...">
                    </div>

                    <!-- 100% Alpine.js Crop Filter -->
                    <?php 
                        $curCropName = 'All Crops (' . count($cropsList) . ')';
                        foreach ($cropsList as $crop) {
                            $cName = $crop['name_en'] ?: $crop['name'];
                            if ($filterCrop === $cName) {
                                $curCropName = $cName . ' (' . $crop['name'] . ')';
                                break;
                            }
                        }
                    ?>
                    <div class="alpine-select-wrapper" x-data="{ open: false, label: '<?= htmlspecialchars(addslashes($curCropName)) ?>', val: '<?= htmlspecialchars(addslashes($filterCrop)) ?>' }" @click.outside="open = false">
                        <input type="hidden" name="crop" :value="val">
                        <div class="alpine-select-trigger" :class="{ 'active': open }" @click="open = !open">
                            <span x-text="label"></span>
                            <i class="ph ph-caret-down"></i>
                        </div>
                        <div class="alpine-select-menu" x-show="open" x-cloak x-transition>
                            <div class="alpine-select-option" :class="{ 'selected': val === 'all' }" @click="label = 'All Crops (<?= count($cropsList) ?>)'; val = 'all'; open = false; $nextTick(() => document.getElementById('varietiesFilterForm').submit())">
                                <span>All Crops (<?= count($cropsList) ?>)</span>
                                <i class="ph-bold ph-check check-icon" x-show="val === 'all'"></i>
                            </div>
                            <?php foreach ($cropsList as $crop): 
                                $cVal = $crop['name_en'] ?: $crop['name'];
                            ?>
                                <div class="alpine-select-option" :class="{ 'selected': val === '<?= htmlspecialchars(addslashes($cVal)) ?>' }" @click="label = '<?= htmlspecialchars(addslashes($cVal . ' (' . $crop['name'] . ')')) ?>'; val = '<?= htmlspecialchars(addslashes($cVal)) ?>'; open = false; $nextTick(() => document.getElementById('varietiesFilterForm').submit())">
                                    <span><?= htmlspecialchars($cVal) ?> (<?= htmlspecialchars($crop['name']) ?>)</span>
                                    <i class="ph-bold ph-check check-icon" x-show="val === '<?= htmlspecialchars(addslashes($cVal)) ?>'"></i>
                                </div>
                            <?php endforeach; ?>
                        </div>
                    </div>

                    <button type="submit" class="btn btn-secondary btn-xs">Filter</button>
                    <?php if (!empty($q) || $filterCrop !== 'all'): ?>
                        <a href="?tab=varieties" class="btn btn-secondary btn-xs">Reset</a>
                    <?php endif; ?>
                </form>

                <div class="action-buttons">
                    <button type="button" @click="openVarietyModal()" class="btn btn-primary">
                        <i class="ph-bold ph-plus"></i> Add Seed Variety
                    </button>
                </div>
            </div>

            <!-- Seed Varieties Table Card -->
            <div class="table-card">
                <div class="table-responsive">
                    <table class="data-table">
                        <thead>
                            <tr>
                                <th>Image</th>
                                <th>Variety Name</th>
                                <th>Crop</th>
                                <th>Price & Packet</th>
                                <th>Vendor / Seller</th>
                                <th>Yield (Q/Acre)</th>
                                <th>Duration</th>
                                <th>Regions & Sowing</th>
                                <th style="text-align: right;">Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php if (empty($varietiesList)): ?>
                                <tr>
                                    <td colspan="9">
                                        <div class="empty-state">
                                            <i class="ph ph-plant"></i>
                                            <p>No seed varieties found.</p>
                                            <button type="button" @click="openVarietyModal()" class="btn btn-primary">
                                                <i class="ph-bold ph-plus"></i> Add First Variety
                                            </button>
                                        </div>
                                    </td>
                                </tr>
                            <?php else: ?>
                                <?php foreach ($varietiesList as $var): ?>
                                    <tr>
                                        <td>
                                            <?php if (!empty($var['image_url'])): ?>
                                                <img src="<?= htmlspecialchars($var['image_url']) ?>" alt="" class="media-thumb" loading="lazy">
                                            <?php else: ?>
                                                <div class="media-thumb-placeholder"><i class="ph ph-plant"></i></div>
                                            <?php endif; ?>
                                        </td>
                                        <td>
                                            <div style="font-weight: 600; color: var(--text-primary);"><?= htmlspecialchars($var['variety_name_en']) ?></div>
                                            <div style="font-size: 0.78rem; color: var(--text-secondary);">
                                                <?= htmlspecialchars($var['variety_name_te'] ?? '') ?>
                                                <?php if (!empty($var['variety_name_hi'])): ?>
                                                    &bull; <?= htmlspecialchars($var['variety_name_hi']) ?>
                                                <?php endif; ?>
                                            </div>
                                            <div style="font-size: 0.72rem; color: var(--text-muted); margin-top: 2px;">
                                                ID: #<?= $var['id'] ?>
                                                <?php if ($var['bookings_count'] > 0): ?>
                                                    &bull; <span style="color: var(--primary-dark); font-weight: 600;"><?= $var['bookings_count'] ?> farmer bookings</span>
                                                <?php endif; ?>
                                            </div>
                                        </td>
                                        <td><span class="badge badge-green"><?= htmlspecialchars($var['crop_name']) ?></span></td>
                                        <td>
                                            <?php if (!empty($var['base_price'])): ?>
                                                <div style="font-weight: 700; color: var(--text-primary);">₹<?= number_format($var['base_price'], 2) ?></div>
                                                <div style="font-size: 0.72rem; color: var(--text-muted);"><?= htmlspecialchars(str_replace('_', ' ', $var['packet_size'] ?? 'per_kg')) ?></div>
                                            <?php else: ?>
                                                <span style="font-size: 0.78rem; color: var(--text-muted);">Unpriced</span>
                                            <?php endif; ?>
                                        </td>
                                        <td>
                                            <div class="uploader-pill">
                                                <i class="ph-fill ph-certificate text-green-600"></i>
                                                <?= htmlspecialchars($var['vendor_name'] ?? 'Cropsync Direct') ?>
                                            </div>
                                            <?php if (isset($var['stock_quantity'])): ?>
                                                <div style="font-size: 0.72rem; color: var(--text-muted); margin-top: 2px;">Stock: <?= $var['stock_quantity'] ?> pkts</div>
                                            <?php endif; ?>
                                        </td>
                                        <td><div style="font-weight: 600;"><?= $var['average_yield'] ? number_format($var['average_yield'], 1) . ' q' : 'N/A' ?></div></td>
                                        <td><div style="font-size: 0.84rem;"><?= $var['growth_duration'] ? $var['growth_duration'] . ' days' : 'N/A' ?></div></td>
                                        <td>
                                            <?php 
                                                $displayRegEn = !empty($var['region_en']) ? $var['region_en'] : (!empty($var['region']) ? $var['region'] : 'All Regions');
                                                $subReg = array_filter([$var['region_te'] ?? '', $var['region_hi'] ?? '']);
                                                $displaySowEn = !empty($var['sowing_period_en']) ? $var['sowing_period_en'] : (!empty($var['sowing_period']) ? $var['sowing_period'] : 'Regular season');
                                                $subSow = array_filter([$var['sowing_period_te'] ?? '', $var['sowing_period_hi'] ?? '']);
                                            ?>
                                            <div style="font-weight: 500; font-size: 0.8rem; color: var(--text-primary); max-width: 190px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;" title="<?= htmlspecialchars($displayRegEn) ?>">
                                                <i class="ph-bold ph-map-pin" style="color: var(--primary); font-size: 0.75rem;"></i>
                                                <?= htmlspecialchars($displayRegEn) ?>
                                            </div>
                                            <?php if (!empty($subReg)): ?>
                                                <div style="font-size: 0.72rem; color: var(--text-muted); max-width: 190px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">
                                                    <?= htmlspecialchars(implode(' • ', $subReg)) ?>
                                                </div>
                                            <?php endif; ?>
                                            <div style="font-size: 0.72rem; color: var(--text-secondary); margin-top: 3px; max-width: 190px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;" title="<?= htmlspecialchars($displaySowEn) ?>">
                                                <i class="ph ph-calendar" style="color: var(--text-muted); font-size: 0.75rem;"></i>
                                                <?= htmlspecialchars($displaySowEn) ?>
                                                <?php if (!empty($subSow)): ?>
                                                    <span style="color: var(--text-muted); font-size: 0.7rem;">(<?= htmlspecialchars(reset($subSow)) ?>)</span>
                                                <?php endif; ?>
                                            </div>
                                        </td>
                                        <td style="text-align: right; white-space: nowrap;">
                                            <button type="button" @click="editVariety(<?= htmlspecialchars(json_encode($var)) ?>)" class="btn btn-secondary btn-xs">
                                                <i class="ph-bold ph-pencil-simple"></i> Edit
                                            </button>
                                            <button type="button" @click="confirmDeleteVariety(<?= $var['id'] ?>, '<?= htmlspecialchars(addslashes($var['variety_name_en'])) ?>')" class="btn btn-danger-outline btn-xs">
                                                <i class="ph-bold ph-trash"></i>
                                            </button>
                                        </td>
                                    </tr>
                                <?php endforeach; ?>
                            <?php endif; ?>
                        </tbody>
                    </table>
                </div>
            </div>

        <?php endif; ?>

        <!-- ============================================================== -->
        <!-- TAB 3: CATEGORIES & CROPS MASTER (MULTILINGUAL WITH TRANSLATION) -->
        <!-- ============================================================== -->
        <?php if ($activeTab === 'categories'): ?>

            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 24px;">

                <!-- Left Column: Product Categories in 3 Languages -->
                <div>
                    <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 14px;">
                        <h2 style="font-size: 1.05rem; font-weight: 700;">
                            <i class="ph-bold ph-tag"></i> Multilingual Product Categories
                        </h2>
                        <div style="display: flex; gap: 8px;">
                            <form method="POST" id="syncCategoriesForm" style="display: inline;">
                                <input type="hidden" name="action" value="sync_categories_products">
                                <button type="button" @click="confirmSyncCategories()" class="btn btn-secondary btn-xs" title="Synchronize all products' category columns with master categories table">
                                    <i class="ph-bold ph-arrows-clockwise"></i> Sync with Products
                                </button>
                            </form>
                            <button type="button" @click="openCreateCategoryModal()" class="btn btn-primary btn-xs">
                                <i class="ph-bold ph-plus"></i> New Category
                            </button>
                        </div>
                    </div>

                    <div class="table-card">
                        <table class="data-table">
                            <thead>
                                <tr>
                                    <th>English</th>
                                    <th>Telugu (తెలుగు)</th>
                                    <th>Hindi (हिन्दी)</th>
                                    <th>Products</th>
                                    <th style="text-align: right;">Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php if (empty($productCategories)): ?>
                                    <tr><td colspan="5" class="empty-state">No categories recorded yet.</td></tr>
                                <?php else: ?>
                                    <?php foreach ($productCategories as $pCat): ?>
                                        <tr>
                                            <td>
                                                <div style="font-weight: 700; color: var(--text-primary);"><?= htmlspecialchars($pCat['category_name_en']) ?></div>
                                            </td>
                                            <td>
                                                <span class="badge badge-blue"><?= htmlspecialchars($pCat['category_name_te']) ?></span>
                                            </td>
                                            <td>
                                                <span style="font-size: 0.82rem; color: var(--text-secondary);"><?= htmlspecialchars($pCat['category_name_hi'] ?: 'N/A') ?></span>
                                            </td>
                                            <td>
                                                <strong><?= $pCat['count'] ?></strong>
                                            </td>
                                            <td style="text-align: right; white-space: nowrap;">
                                                <button type="button" @click="editCategory(<?= htmlspecialchars(json_encode($pCat)) ?>)" class="btn btn-secondary btn-xs">
                                                    <i class="ph-bold ph-pencil-simple"></i> Edit
                                                </button>
                                                <button type="button" @click="confirmDeleteCategory(<?= $pCat['id'] ?>, '<?= htmlspecialchars(addslashes($pCat['category_name_en'])) ?>')" class="btn btn-danger-outline btn-xs">
                                                    <i class="ph-bold ph-trash"></i>
                                                </button>
                                            </td>
                                        </tr>
                                    <?php endforeach; ?>
                                <?php endif; ?>
                            </tbody>
                        </table>
                    </div>
                </div>

                <!-- Right Column: Agricultural Crops Master -->
                <div>
                    <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 14px;">
                        <h2 style="font-size: 1.05rem; font-weight: 700;">
                            <i class="ph-bold ph-plant"></i> Agricultural Crops Master
                        </h2>
                        <button type="button" @click="openCropModal()" class="btn btn-primary btn-xs">
                            <i class="ph-bold ph-plus"></i> Add Crop
                        </button>
                    </div>

                    <div class="table-card">
                        <table class="data-table">
                            <thead>
                                <tr>
                                    <th>Image</th>
                                    <th>Crop Name (EN / TE / HI)</th>
                                    <th>Varieties</th>
                                    <th style="text-align: right;">Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php if (empty($cropsList)): ?>
                                    <tr><td colspan="4" class="empty-state">No crops found in master database.</td></tr>
                                <?php else: ?>
                                    <?php foreach ($cropsList as $cropItem): ?>
                                        <tr>
                                            <td>
                                                <?php if (!empty($cropItem['image_url'])): ?>
                                                    <img src="<?= htmlspecialchars($cropItem['image_url']) ?>" alt="" class="media-thumb" loading="lazy">
                                                <?php else: ?>
                                                    <div class="media-thumb-placeholder"><i class="ph ph-plant"></i></div>
                                                <?php endif; ?>
                                            </td>
                                            <td>
                                                <div style="font-weight: 600;"><?= htmlspecialchars($cropItem['name_en'] ?: $cropItem['name']) ?></div>
                                                <div style="font-size: 0.78rem; color: var(--text-secondary);">
                                                    <?= htmlspecialchars($cropItem['name']) ?>
                                                    <?php if (!empty($cropItem['name_hi'])): ?>
                                                        &bull; <?= htmlspecialchars($cropItem['name_hi']) ?>
                                                    <?php endif; ?>
                                                </div>
                                            </td>
                                            <td><span class="badge badge-green"><?= $cropItem['varieties_count'] ?> varieties</span></td>
                                            <td style="text-align: right; white-space: nowrap;">
                                                <button type="button" @click="editCrop(<?= htmlspecialchars(json_encode($cropItem)) ?>)" class="btn btn-secondary btn-xs">
                                                    <i class="ph-bold ph-pencil-simple"></i> Edit
                                                </button>
                                                <button type="button" @click="confirmDeleteCrop(<?= $cropItem['id'] ?>, '<?= htmlspecialchars(addslashes($cropItem['name_en'] ?: $cropItem['name'])) ?>')" class="btn btn-danger-outline btn-xs">
                                                    <i class="ph-bold ph-trash"></i>
                                                </button>
                                            </td>
                                        </tr>
                                    <?php endforeach; ?>
                                <?php endif; ?>
                            </tbody>
                        </table>
                    </div>
                </div>

            </div>

        <?php endif; ?>

        <!-- ============================================================== -->
        <!-- TAB 4: VENDORS & ADVERTISERS DIRECTORY -->
        <!-- ============================================================== -->
        <?php if ($activeTab === 'uploaders'): ?>

            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 24px;">

                <!-- Advertisers List -->
                <div>
                    <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 14px;">
                        <h2 style="font-size: 1.05rem; font-weight: 700;">
                            <i class="ph-bold ph-storefront"></i> Agri Shop Advertisers
                        </h2>
                        <button type="button" @click="openAdvertiserModal()" class="btn btn-primary btn-xs">
                            <i class="ph-bold ph-plus"></i> New Advertiser
                        </button>
                    </div>

                    <div class="table-card">
                        <table class="data-table">
                            <thead>
                                <tr>
                                    <th>Advertiser Code</th>
                                    <th>Company Name</th>
                                    <th>Email</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php foreach ($advertisers as $adv): ?>
                                    <tr>
                                        <td><span class="badge badge-gray"><?= htmlspecialchars($adv['advertiser_code']) ?></span></td>
                                        <td>
                                            <div style="font-weight: 600;"><?= htmlspecialchars($adv['advertiser_name']) ?></div>
                                            <div style="font-size: 0.72rem; color: var(--text-muted);">ID #<?= $adv['advertiser_id'] ?></div>
                                        </td>
                                        <td><span style="font-size: 0.8rem; color: var(--text-secondary);"><?= htmlspecialchars($adv['email_address']) ?></span></td>
                                    </tr>
                                <?php endforeach; ?>
                            </tbody>
                        </table>
                    </div>
                </div>

                <!-- Seed Vendors List -->
                <div>
                    <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 14px;">
                        <h2 style="font-size: 1.05rem; font-weight: 700;">
                            <i class="ph-bold ph-certificate"></i> Seed Vendors / Suppliers
                        </h2>
                        <button type="button" @click="openVendorModal()" class="btn btn-primary btn-xs">
                            <i class="ph-bold ph-plus"></i> New Vendor
                        </button>
                    </div>

                    <div class="table-card">
                        <table class="data-table">
                            <thead>
                                <tr>
                                    <th>Company Name</th>
                                    <th>License / Contact</th>
                                    <th>Status</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php foreach ($vendors as $ven): ?>
                                    <tr>
                                        <td>
                                            <div style="font-weight: 600;"><?= htmlspecialchars($ven['company_name']) ?></div>
                                            <div style="font-size: 0.72rem; color: var(--text-muted);">ID #<?= $ven['id'] ?></div>
                                        </td>
                                        <td>
                                            <div><?= htmlspecialchars($ven['contact_number']) ?></div>
                                            <div style="font-size: 0.72rem; color: var(--text-muted);">Lic: <?= htmlspecialchars($ven['license_number'] ?? 'N/A') ?></div>
                                        </td>
                                        <td>
                                            <span class="badge <?= $ven['is_verified'] ? 'badge-green' : 'badge-amber' ?>">
                                                <?= $ven['is_verified'] ? 'Verified' : 'Pending' ?>
                                            </span>
                                        </td>
                                    </tr>
                                <?php endforeach; ?>
                            </tbody>
                        </table>
                    </div>
                </div>

            </div>

        <?php endif; ?>

        <!-- ============================================================== -->
        <!-- TAB 5: LEADS & SEED BOOKINGS (FIXED FETCH & 100% ALPINE DROPDOWNS) -->
        <!-- ============================================================== -->
        <?php if ($activeTab === 'leads'): ?>

            <div style="display: flex; flex-direction: column; gap: 28px;">

                <!-- Product Enquiries -->
                <div>
                    <h2 style="font-size: 1.05rem; font-weight: 700; margin-bottom: 12px; display: flex; align-items: center; gap: 8px;">
                        <i class="ph-bold ph-shopping-cart text-emerald-600"></i> Agri Shop Product Enquiries (<?= count($enquiriesList) ?>)
                    </h2>

                    <div class="table-card">
                        <div class="table-responsive">
                            <table class="data-table">
                                <thead>
                                    <tr>
                                        <th>Enquiry ID</th>
                                        <th>Product</th>
                                        <th>Advertiser</th>
                                        <th>Farmer / Contact</th>
                                        <th>Date</th>
                                        <th>Status</th>
                                        <th style="text-align: right;">Update Status</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <?php if (empty($enquiriesList)): ?>
                                        <tr><td colspan="7" class="empty-state">No enquiries received yet.</td></tr>
                                    <?php else: ?>
                                        <?php foreach ($enquiriesList as $enq): ?>
                                            <tr>
                                                <td>#<?= $enq['enquiry_id'] ?></td>
                                                <td>
                                                    <div style="font-weight: 600;"><?= htmlspecialchars($enq['product_name_en'] ?: $enq['product_name']) ?></div>
                                                </td>
                                                <td>
                                                    <span class="uploader-pill"><?= htmlspecialchars($enq['advertiser_name'] ?? 'Advertiser') ?></span>
                                                </td>
                                                <td>
                                                    <div><?= htmlspecialchars($enq['farmer_name'] ?: 'Farmer') ?></div>
                                                    <div style="font-size: 0.76rem; color: var(--text-muted);"><?= htmlspecialchars($enq['farmer_phone'] ?? $enq['farmer_id']) ?></div>
                                                </td>
                                                <td style="font-size: 0.8rem; color: var(--text-secondary);">
                                                    <?= htmlspecialchars($enq['enquiry_date']) ?>
                                                </td>
                                                <td>
                                                    <span class="badge <?= $enq['status'] === 'Contacted' ? 'badge-blue' : ($enq['status'] === 'Completed' ? 'badge-green' : 'badge-amber') ?>">
                                                        <?= htmlspecialchars($enq['status']) ?>
                                                    </span>
                                                </td>
                                                <td style="text-align: right;">
                                                    <!-- 100% Alpine.js Status Select -->
                                                    <form method="POST" id="enqForm_<?= $enq['enquiry_id'] ?>" style="display:inline-block;">
                                                        <input type="hidden" name="action" value="update_enquiry_status">
                                                        <input type="hidden" name="enquiry_id" value="<?= $enq['enquiry_id'] ?>">
                                                        <div class="alpine-select-wrapper" x-data="{ open: false, label: '<?= htmlspecialchars(addslashes($enq['status'])) ?>', val: '<?= htmlspecialchars(addslashes($enq['status'])) ?>' }" @click.outside="open = false">
                                                            <input type="hidden" name="status" :value="val">
                                                            <div class="alpine-select-trigger" style="min-width: 110px; padding: 4px 8px; font-size: 0.78rem;" :class="{ 'active': open }" @click="open = !open">
                                                                <span x-text="label"></span>
                                                                <i class="ph ph-caret-down"></i>
                                                            </div>
                                                            <div class="alpine-select-menu right-align" x-show="open" x-cloak x-transition>
                                                                <div class="alpine-select-option" @click="label = 'Interested'; val = 'Interested'; open = false; $nextTick(() => document.getElementById('enqForm_<?= $enq['enquiry_id'] ?>').submit())">Interested</div>
                                                                <div class="alpine-select-option" @click="label = 'Contacted'; val = 'Contacted'; open = false; $nextTick(() => document.getElementById('enqForm_<?= $enq['enquiry_id'] ?>').submit())">Contacted</div>
                                                                <div class="alpine-select-option" @click="label = 'Completed'; val = 'Completed'; open = false; $nextTick(() => document.getElementById('enqForm_<?= $enq['enquiry_id'] ?>').submit())">Completed</div>
                                                                <div class="alpine-select-option" @click="label = 'Cancelled'; val = 'Cancelled'; open = false; $nextTick(() => document.getElementById('enqForm_<?= $enq['enquiry_id'] ?>').submit())">Cancelled</div>
                                                            </div>
                                                        </div>
                                                    </form>
                                                </td>
                                            </tr>
                                        <?php endforeach; ?>
                                    <?php endif; ?>
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>

                <!-- Seed Bookings (Fixed Query & 100% Alpine Select) -->
                <div>
                    <h2 style="font-size: 1.05rem; font-weight: 700; margin-bottom: 12px; display: flex; align-items: center; gap: 8px;">
                        <i class="ph-bold ph-plant text-green-600"></i> Seed Variety Bookings (<?= count($bookingsList) ?>)
                    </h2>

                    <div class="table-card">
                        <div class="table-responsive">
                            <table class="data-table">
                                <thead>
                                    <tr>
                                        <th>Booking Code</th>
                                        <th>Crop & Variety</th>
                                        <th>Farmer / Contact</th>
                                        <th>Quantity</th>
                                        <th>Total Price</th>
                                        <th>Region</th>
                                        <th>Timestamp</th>
                                        <th>Status</th>
                                        <th style="text-align: right;">Update Status</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <?php if (empty($bookingsList)): ?>
                                        <tr><td colspan="9" class="empty-state">No seed bookings found in database.</td></tr>
                                    <?php else: ?>
                                        <?php foreach ($bookingsList as $bkg): ?>
                                            <tr>
                                                <td>
                                                    <span class="badge badge-gray"><?= htmlspecialchars($bkg['booking_id']) ?></span>
                                                </td>
                                                <td>
                                                    <div style="font-weight: 600;"><?= htmlspecialchars($bkg['variety_name_en'] ?? 'Seed Variety') ?></div>
                                                    <div style="font-size: 0.74rem; color: var(--text-muted);">
                                                        <?= htmlspecialchars($bkg['crop_name'] ?? '') ?>
                                                        <?php if (!empty($bkg['variety_name_te'])): ?>
                                                            &bull; <?= htmlspecialchars($bkg['variety_name_te']) ?>
                                                        <?php endif; ?>
                                                    </div>
                                                </td>
                                                <td>
                                                    <div><?= htmlspecialchars($bkg['farmer_name'] ?: 'Farmer') ?></div>
                                                    <div style="font-size: 0.76rem; color: var(--text-muted);"><?= htmlspecialchars($bkg['farmer_phone'] ?? $bkg['user_id']) ?></div>
                                                </td>
                                                <td><strong><?= $bkg['quantity_kg'] ?></strong> kg</td>
                                                <td><strong>₹<?= number_format($bkg['total_price'], 2) ?></strong></td>
                                                <td style="font-size: 0.8rem; color: var(--text-secondary);"><?= htmlspecialchars($bkg['user_region'] ?: 'N/A') ?></td>
                                                <td style="font-size: 0.76rem; color: var(--text-muted);"><?= htmlspecialchars($bkg['booking_timestamp']) ?></td>
                                                <td>
                                                    <span class="badge <?= $bkg['booking_status'] === 'confirmed' ? 'badge-green' : ($bkg['booking_status'] === 'shipped' ? 'badge-blue' : ($bkg['booking_status'] === 'delivered' ? 'badge-green' : ($bkg['booking_status'] === 'cancelled' ? 'badge-red' : 'badge-amber'))) ?>">
                                                        <?= htmlspecialchars(ucfirst($bkg['booking_status'])) ?>
                                                    </span>
                                                </td>
                                                <td style="text-align: right;">
                                                    <!-- 100% Alpine.js Booking Status Select -->
                                                    <form method="POST" id="bkForm_<?= htmlspecialchars($bkg['booking_id']) ?>" style="display:inline-block;">
                                                        <input type="hidden" name="action" value="update_booking_status">
                                                        <input type="hidden" name="booking_id" value="<?= htmlspecialchars($bkg['booking_id']) ?>">
                                                        <div class="alpine-select-wrapper" x-data="{ open: false, label: '<?= ucfirst($bkg['booking_status']) ?>', val: '<?= $bkg['booking_status'] ?>' }" @click.outside="open = false">
                                                            <input type="hidden" name="booking_status" :value="val">
                                                            <div class="alpine-select-trigger" style="min-width: 115px; padding: 4px 8px; font-size: 0.78rem;" :class="{ 'active': open }" @click="open = !open">
                                                                <span x-text="label"></span>
                                                                <i class="ph ph-caret-down"></i>
                                                            </div>
                                                            <div class="alpine-select-menu right-align" x-show="open" x-cloak x-transition>
                                                                <div class="alpine-select-option" @click="label = 'Pending'; val = 'pending'; open = false; $nextTick(() => document.getElementById('bkForm_<?= htmlspecialchars($bkg['booking_id']) ?>').submit())">Pending</div>
                                                                <div class="alpine-select-option" @click="label = 'Confirmed'; val = 'confirmed'; open = false; $nextTick(() => document.getElementById('bkForm_<?= htmlspecialchars($bkg['booking_id']) ?>').submit())">Confirmed</div>
                                                                <div class="alpine-select-option" @click="label = 'Shipped'; val = 'shipped'; open = false; $nextTick(() => document.getElementById('bkForm_<?= htmlspecialchars($bkg['booking_id']) ?>').submit())">Shipped</div>
                                                                <div class="alpine-select-option" @click="label = 'Delivered'; val = 'delivered'; open = false; $nextTick(() => document.getElementById('bkForm_<?= htmlspecialchars($bkg['booking_id']) ?>').submit())">Delivered</div>
                                                                <div class="alpine-select-option" @click="label = 'Cancelled'; val = 'cancelled'; open = false; $nextTick(() => document.getElementById('bkForm_<?= htmlspecialchars($bkg['booking_id']) ?>').submit())">Cancelled</div>
                                                            </div>
                                                        </div>
                                                    </form>
                                                </td>
                                            </tr>
                                        <?php endforeach; ?>
                                    <?php endif; ?>
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>

            </div>

        <?php endif; ?>

    </main>

    <!-- ============================================================== -->
    <!-- MODAL: ADD / EDIT PRODUCT (100% ALPINE DROPDOWNS & AUTO-TRANSLATE) -->
    <!-- ============================================================== -->
    <div class="modal-overlay" x-show="showProductModal" x-cloak @click.self="showProductModal = false">
        <div class="modal-container">
            <div class="modal-header">
                <h3 x-text="productForm.product_id > 0 ? 'Edit Agri Shop Product #' + productForm.product_id : 'Add New Agri Shop Product'"></h3>
                <button type="button" @click="showProductModal = false" style="background:none; border:none; font-size:1.4rem; cursor:pointer;">&times;</button>
            </div>

            <form method="POST" enctype="multipart/form-data">
                <input type="hidden" name="action" value="save_product">
                <input type="hidden" name="product_id" :value="productForm.product_id">

                <div class="modal-body">
                    <div class="form-grid">

                        <!-- 100% Alpine.js Assigned Advertiser Dropdown -->
                        <div class="form-group">
                            <label class="form-label">Assigned Advertiser / Company *</label>
                            <input type="hidden" name="advertiser_id" :value="productForm.advertiser_id">
                            <div class="alpine-select-wrapper full-width" x-data="{ open: false }" @click.outside="open = false">
                                <div class="alpine-select-trigger" :class="{ 'active': open }" @click="open = !open">
                                    <span x-text="getAdvertiserName(productForm.advertiser_id)"></span>
                                    <i class="ph ph-caret-down"></i>
                                </div>
                                <div class="alpine-select-menu" x-show="open" x-cloak x-transition>
                                    <template x-for="adv in advertisersList" :key="adv.advertiser_id">
                                        <div class="alpine-select-option" :class="{ 'selected': productForm.advertiser_id == adv.advertiser_id }" @click="productForm.advertiser_id = adv.advertiser_id; open = false;">
                                            <span x-text="adv.advertiser_name + ' (' + adv.advertiser_code + ')'"></span>
                                            <i class="ph-bold ph-check check-icon" x-show="productForm.advertiser_id == adv.advertiser_id"></i>
                                        </div>
                                    </template>
                                </div>
                            </div>
                        </div>

                        <!-- 100% Alpine.js Multilingual Category Dropdown -->
                        <div class="form-group">
                            <label class="form-label">Category *</label>
                            <input type="hidden" name="category" :value="productForm.category">
                            <input type="hidden" name="category_en" :value="productForm.category_en">
                            <input type="hidden" name="category_hi" :value="productForm.category_hi">
                            <div class="alpine-select-wrapper full-width" x-data="{ open: false }" @click.outside="open = false">
                                <div class="alpine-select-trigger" :class="{ 'active': open }" @click="open = !open">
                                    <span x-text="getCategoryLabel(productForm.category, productForm.category_en)"></span>
                                    <i class="ph ph-caret-down"></i>
                                </div>
                                <div class="alpine-select-menu" x-show="open" x-cloak x-transition>
                                    <template x-for="cat in categoriesList" :key="cat.id">
                                        <div class="alpine-select-option" :class="{ 'selected': productForm.category === cat.category_name_te || productForm.category_en === cat.category_name_en }" @click="selectCategory(cat); open = false;">
                                            <span x-text="cat.category_name_en + ' (' + cat.category_name_te + ')'"></span>
                                            <i class="ph-bold ph-check check-icon" x-show="productForm.category === cat.category_name_te || productForm.category_en === cat.category_name_en"></i>
                                        </div>
                                    </template>
                                </div>
                            </div>
                        </div>

                        <!-- Product Code -->
                        <div class="form-group">
                            <label class="form-label">Product Code (Optional)</label>
                            <input type="text" name="product_code" x-model="productForm.product_code" class="form-input" placeholder="Auto-generated if blank">
                        </div>

                        <!-- 100% Alpine.js Region Dropdown -->
                        <div class="form-group">
                            <label class="form-label">Available Region</label>
                            <input type="hidden" name="region_id" :value="productForm.region_id">
                            <div class="alpine-select-wrapper full-width" x-data="{ open: false }" @click.outside="open = false">
                                <div class="alpine-select-trigger" :class="{ 'active': open }" @click="open = !open">
                                    <span x-text="getRegionName(productForm.region_id)"></span>
                                    <i class="ph ph-caret-down"></i>
                                </div>
                                <div class="alpine-select-menu" x-show="open" x-cloak x-transition>
                                    <div class="alpine-select-option" :class="{ 'selected': !productForm.region_id }" @click="productForm.region_id = ''; open = false;">
                                        <span>All Regions</span>
                                        <i class="ph-bold ph-check check-icon" x-show="!productForm.region_id"></i>
                                    </div>
                                    <template x-for="reg in regionsList" :key="reg.id">
                                        <div class="alpine-select-option" :class="{ 'selected': productForm.region_id == reg.id }" @click="productForm.region_id = reg.id; open = false;">
                                            <span x-text="reg.region_name"></span>
                                            <i class="ph-bold ph-check check-icon" x-show="productForm.region_id == reg.id"></i>
                                        </div>
                                    </template>
                                </div>
                            </div>
                        </div>

                        <!-- Product Name English with Auto-Translator -->
                        <div class="form-group full">
                            <label class="form-label">
                                Product Name (English) *
                                <button type="button" @click="autoTranslateProduct()" class="btn-translate" :disabled="isTranslating">
                                    <i class="ph-bold" :class="isTranslating ? 'ph-spinner-gap spin' : 'ph-translate'"></i>
                                    <span x-text="isTranslating ? 'Translating...' : 'Auto-Translate to Telugu & Hindi'"></span>
                                </button>
                            </label>
                            <input type="text" name="product_name_en" x-model="productForm.product_name_en" class="form-input" placeholder="e.g. Solar Insect Trap" required>
                        </div>

                        <!-- Product Name Telugu -->
                        <div class="form-group">
                            <label class="form-label">Product Name (Telugu - తెలుగు)</label>
                            <input type="text" name="product_name" x-model="productForm.product_name" class="form-input" placeholder="తెలుగు పేరు">
                        </div>

                        <!-- Product Name Hindi -->
                        <div class="form-group">
                            <label class="form-label">Product Name (Hindi - हिन्दी)</label>
                            <input type="text" name="product_name_hi" x-model="productForm.product_name_hi" class="form-input" placeholder="हिन्दी नाम">
                        </div>

                        <!-- Selling Price -->
                        <div class="form-group">
                            <label class="form-label">Selling Price (₹) *</label>
                            <input type="number" step="0.01" name="price" x-model="productForm.price" class="form-input" required>
                        </div>

                        <!-- MRP -->
                        <div class="form-group">
                            <label class="form-label">MRP (₹, Optional)</label>
                            <input type="number" step="0.01" name="mrp" x-model="productForm.mrp" class="form-input" placeholder="Higher than selling price">
                        </div>

                        <!-- In Stock & Active Toggles -->
                        <div class="form-group" style="flex-direction:row; align-items:center; gap:12px; margin-top:10px;">
                            <label style="display:flex; align-items:center; gap:8px; cursor:pointer; font-size:0.86rem; font-weight:600;">
                                <input type="checkbox" name="in_stock" x-model="productForm.in_stock" value="1"> In Stock
                            </label>
                            <label style="display:flex; align-items:center; gap:8px; cursor:pointer; font-size:0.86rem; font-weight:600;">
                                <input type="checkbox" name="is_active" x-model="productForm.is_active" value="1"> Active & Visible
                            </label>
                        </div>

                        <!-- Primary Image -->
                        <div class="form-group full">
                            <label class="form-label">Primary Image</label>
                            <div class="media-upload-card" :class="{ 'dragover': dragOver }"
                                 x-data="mediaUploader({ uploadType: 'products', isVideo: false })"
                                 x-init="url = productForm.image_url_1 || ''; $watch('productForm.image_url_1', val => url = val || ''); $watch('url', val => productForm.image_url_1 = val)"
                                 @dragover.prevent="dragOver = true" @dragleave.prevent="dragOver = false" @drop.prevent="dragOver = false; upload($event.dataTransfer.files[0])">
                                <div class="media-input-row">
                                    <template x-if="url">
                                        <div class="media-preview-thumb">
                                            <img :src="url" alt="Preview">
                                            <button type="button" class="media-clear-btn" @click="clear()" title="Remove">&times;</button>
                                        </div>
                                    </template>
                                    <template x-if="!url">
                                        <div class="media-preview-placeholder">
                                            <i class="ph ph-image"></i>
                                        </div>
                                    </template>
                                    <input type="text" name="image_url_1" x-model="url" class="form-input media-url-input" placeholder="Paste image URL or click Upload...">
                                    <input type="file" x-ref="fileInput" style="display:none;" accept="image/*" @change="upload($event.target.files[0]); $event.target.value=''">
                                    <button type="button" class="btn-upload" @click="$refs.fileInput.click()" :disabled="isUploading">
                                        <i class="ph-bold" :class="isUploading ? 'ph-spinner-gap spin' : 'ph-cloud-arrow-up'"></i>
                                        <span x-text="isUploading ? progress + '%' : 'Upload Image'"></span>
                                    </button>
                                </div>
                                <div class="media-progress-bar-wrap" x-show="isUploading" x-cloak>
                                    <div class="media-progress-bar-fill" :style="'width: ' + progress + '%'"></div>
                                </div>
                                <div class="media-status-text" :class="statusType" x-show="statusText" x-cloak x-text="statusText"></div>
                            </div>
                        </div>

                        <!-- Image 2 -->
                        <div class="form-group">
                            <label class="form-label">Image 2 (Optional)</label>
                            <div class="media-upload-card" :class="{ 'dragover': dragOver }"
                                 x-data="mediaUploader({ uploadType: 'products', isVideo: false })"
                                 x-init="url = productForm.image_url_2 || ''; $watch('productForm.image_url_2', val => url = val || ''); $watch('url', val => productForm.image_url_2 = val)"
                                 @dragover.prevent="dragOver = true" @dragleave.prevent="dragOver = false" @drop.prevent="dragOver = false; upload($event.dataTransfer.files[0])">
                                <div class="media-input-row">
                                    <template x-if="url">
                                        <div class="media-preview-thumb">
                                            <img :src="url" alt="Preview">
                                            <button type="button" class="media-clear-btn" @click="clear()" title="Remove">&times;</button>
                                        </div>
                                    </template>
                                    <template x-if="!url">
                                        <div class="media-preview-placeholder">
                                            <i class="ph ph-image"></i>
                                        </div>
                                    </template>
                                    <input type="text" name="image_url_2" x-model="url" class="form-input media-url-input" placeholder="Paste image URL or click Upload...">
                                    <input type="file" x-ref="fileInput" style="display:none;" accept="image/*" @change="upload($event.target.files[0]); $event.target.value=''">
                                    <button type="button" class="btn-upload" @click="$refs.fileInput.click()" :disabled="isUploading">
                                        <i class="ph-bold" :class="isUploading ? 'ph-spinner-gap spin' : 'ph-cloud-arrow-up'"></i>
                                        <span x-text="isUploading ? progress + '%' : 'Upload Image'"></span>
                                    </button>
                                </div>
                                <div class="media-progress-bar-wrap" x-show="isUploading" x-cloak>
                                    <div class="media-progress-bar-fill" :style="'width: ' + progress + '%'"></div>
                                </div>
                                <div class="media-status-text" :class="statusType" x-show="statusText" x-cloak x-text="statusText"></div>
                            </div>
                        </div>

                        <!-- Image 3 -->
                        <div class="form-group">
                            <label class="form-label">Image 3 (Optional)</label>
                            <div class="media-upload-card" :class="{ 'dragover': dragOver }"
                                 x-data="mediaUploader({ uploadType: 'products', isVideo: false })"
                                 x-init="url = productForm.image_url_3 || ''; $watch('productForm.image_url_3', val => url = val || ''); $watch('url', val => productForm.image_url_3 = val)"
                                 @dragover.prevent="dragOver = true" @dragleave.prevent="dragOver = false" @drop.prevent="dragOver = false; upload($event.dataTransfer.files[0])">
                                <div class="media-input-row">
                                    <template x-if="url">
                                        <div class="media-preview-thumb">
                                            <img :src="url" alt="Preview">
                                            <button type="button" class="media-clear-btn" @click="clear()" title="Remove">&times;</button>
                                        </div>
                                    </template>
                                    <template x-if="!url">
                                        <div class="media-preview-placeholder">
                                            <i class="ph ph-image"></i>
                                        </div>
                                    </template>
                                    <input type="text" name="image_url_3" x-model="url" class="form-input media-url-input" placeholder="Paste image URL or click Upload...">
                                    <input type="file" x-ref="fileInput" style="display:none;" accept="image/*" @change="upload($event.target.files[0]); $event.target.value=''">
                                    <button type="button" class="btn-upload" @click="$refs.fileInput.click()" :disabled="isUploading">
                                        <i class="ph-bold" :class="isUploading ? 'ph-spinner-gap spin' : 'ph-cloud-arrow-up'"></i>
                                        <span x-text="isUploading ? progress + '%' : 'Upload Image'"></span>
                                    </button>
                                </div>
                                <div class="media-progress-bar-wrap" x-show="isUploading" x-cloak>
                                    <div class="media-progress-bar-fill" :style="'width: ' + progress + '%'"></div>
                                </div>
                                <div class="media-status-text" :class="statusType" x-show="statusText" x-cloak x-text="statusText"></div>
                            </div>
                        </div>

                        <!-- Product Demo Video -->
                        <div class="form-group full">
                            <label class="form-label">Product Demo Video (Optional)</label>
                            <div class="media-upload-card" :class="{ 'dragover': dragOver }"
                                 x-data="mediaUploader({ uploadType: 'videos', isVideo: true })"
                                 x-init="url = productForm.product_video_url || ''; $watch('productForm.product_video_url', val => url = val || ''); $watch('url', val => productForm.product_video_url = val)"
                                 @dragover.prevent="dragOver = true" @dragleave.prevent="dragOver = false" @drop.prevent="dragOver = false; upload($event.dataTransfer.files[0])">
                                <div class="media-input-row">
                                    <template x-if="url">
                                        <div class="media-preview-thumb video-preview">
                                            <i class="ph-fill ph-video-camera"></i>
                                            <button type="button" class="media-clear-btn" @click="clear()" title="Remove">&times;</button>
                                        </div>
                                    </template>
                                    <template x-if="!url">
                                        <div class="media-preview-placeholder">
                                            <i class="ph ph-video"></i>
                                        </div>
                                    </template>
                                    <input type="text" name="product_video_url" x-model="url" class="form-input media-url-input" placeholder="Paste video URL or click Upload MP4/WebM...">
                                    <input type="file" x-ref="fileInput" style="display:none;" accept="video/*" @change="upload($event.target.files[0]); $event.target.value=''">
                                    <button type="button" class="btn-upload" @click="$refs.fileInput.click()" :disabled="isUploading">
                                        <i class="ph-bold" :class="isUploading ? 'ph-spinner-gap spin' : 'ph-video-camera'"></i>
                                        <span x-text="isUploading ? progress + '%' : 'Upload Video'"></span>
                                    </button>
                                </div>
                                <div class="media-progress-bar-wrap" x-show="isUploading" x-cloak>
                                    <div class="media-progress-bar-fill" :style="'width: ' + progress + '%'"></div>
                                </div>
                                <div class="media-status-text" :class="statusType" x-show="statusText" x-cloak x-text="statusText"></div>
                            </div>
                        </div>

                        <!-- Descriptions (EN, TE, HI) with Auto-Translate -->
                        <div class="form-group full">
                            <label class="form-label">
                                Description (English)
                                <button type="button" @click="autoTranslateProduct()" class="btn-translate" :disabled="isTranslating">
                                    <i class="ph-bold" :class="isTranslating ? 'ph-spinner-gap spin' : 'ph-translate'"></i>
                                    <span x-text="isTranslating ? 'Translating...' : 'Auto-Translate Description'"></span>
                                </button>
                            </label>
                            <textarea name="product_description_en" x-model="productForm.product_description_en" class="form-textarea" placeholder="Product details..."></textarea>
                        </div>

                        <div class="form-group">
                            <label class="form-label">Description (Telugu - తెలుగు)</label>
                            <textarea name="product_description" x-model="productForm.product_description" class="form-textarea" placeholder="ఉత్పత్తి వివరాలు..."></textarea>
                        </div>

                        <div class="form-group">
                            <label class="form-label">Description (Hindi - हिन्दी)</label>
                            <textarea name="product_description_hi" x-model="productForm.product_description_hi" class="form-textarea" placeholder="उत्पाद विवरण..."></textarea>
                        </div>

                    </div>
                </div>

                <div class="modal-footer">
                    <button type="button" @click="showProductModal = false" class="btn btn-secondary">Cancel</button>
                    <button type="submit" class="btn btn-primary">Save Product</button>
                </div>
            </form>
        </div>
    </div>

    <!-- ============================================================== -->
    <!-- MODAL: ADD / EDIT SEED VARIETY (100% ALPINE DROPDOWNS & AUTO-TRANSLATE) -->
    <!-- ============================================================== -->
    <div class="modal-overlay" x-show="showVarietyModal" x-cloak @click.self="showVarietyModal = false">
        <div class="modal-container">
            <div class="modal-header">
                <h3 x-text="varietyForm.variety_id > 0 ? 'Edit Seed Variety #' + varietyForm.variety_id : 'Add New Seed Variety'"></h3>
                <button type="button" @click="showVarietyModal = false" style="background:none; border:none; font-size:1.4rem; cursor:pointer;">&times;</button>
            </div>

            <form method="POST" enctype="multipart/form-data">
                <input type="hidden" name="action" value="save_variety">
                <input type="hidden" name="variety_id" :value="varietyForm.variety_id">

                <div class="modal-body">
                    <div class="form-grid">

                        <!-- 100% Alpine.js Crop Selector -->
                        <div class="form-group">
                            <label class="form-label">Crop Name *</label>
                            <input type="hidden" name="crop_name" :value="varietyForm.crop_name">
                            <div class="alpine-select-wrapper full-width" x-data="{ open: false }" @click.outside="open = false">
                                <div class="alpine-select-trigger" :class="{ 'active': open }" @click="open = !open">
                                    <span x-text="varietyForm.crop_name"></span>
                                    <i class="ph ph-caret-down"></i>
                                </div>
                                <div class="alpine-select-menu" x-show="open" x-cloak x-transition>
                                    <template x-for="crop in cropsMasterList" :key="crop.id">
                                        <div class="alpine-select-option" :class="{ 'selected': varietyForm.crop_name === (crop.name_en || crop.name) }" @click="varietyForm.crop_name = (crop.name_en || crop.name); open = false;">
                                            <span x-text="(crop.name_en || crop.name) + ' (' + crop.name + ')'"></span>
                                            <i class="ph-bold ph-check check-icon" x-show="varietyForm.crop_name === (crop.name_en || crop.name)"></i>
                                        </div>
                                    </template>
                                </div>
                            </div>
                        </div>

                        <!-- 100% Alpine.js Seed Vendor Partner -->
                        <div class="form-group">
                            <label class="form-label">Seed Vendor / Supplier *</label>
                            <input type="hidden" name="vendor_id" :value="varietyForm.vendor_id">
                            <div class="alpine-select-wrapper full-width" x-data="{ open: false }" @click.outside="open = false">
                                <div class="alpine-select-trigger" :class="{ 'active': open }" @click="open = !open">
                                    <span x-text="getVendorName(varietyForm.vendor_id)"></span>
                                    <i class="ph ph-caret-down"></i>
                                </div>
                                <div class="alpine-select-menu" x-show="open" x-cloak x-transition>
                                    <template x-for="ven in vendorsList" :key="ven.id">
                                        <div class="alpine-select-option" :class="{ 'selected': varietyForm.vendor_id == ven.id }" @click="varietyForm.vendor_id = ven.id; open = false;">
                                            <span x-text="ven.company_name"></span>
                                            <i class="ph-bold ph-check check-icon" x-show="varietyForm.vendor_id == ven.id"></i>
                                        </div>
                                    </template>
                                </div>
                            </div>
                        </div>

                        <!-- Variety Name English with Auto-Translator -->
                        <div class="form-group full">
                            <label class="form-label">
                                Variety Name (English) *
                                <button type="button" @click="autoTranslateVariety()" class="btn-translate" :disabled="isTranslating">
                                    <i class="ph-bold" :class="isTranslating ? 'ph-spinner-gap spin' : 'ph-translate'"></i>
                                    <span x-text="isTranslating ? 'Translating...' : 'Auto-Translate to Telugu & Hindi'"></span>
                                </button>
                            </label>
                            <input type="text" name="variety_name_en" x-model="varietyForm.variety_name_en" class="form-input" placeholder="e.g. Samba Mahsuri / BPT 5204" required>
                        </div>

                        <!-- Variety Name Telugu -->
                        <div class="form-group">
                            <label class="form-label">Variety Name (Telugu - తెలుగు)</label>
                            <input type="text" name="variety_name_te" x-model="varietyForm.variety_name_te" class="form-input" placeholder="రకం పేరు">
                        </div>

                        <!-- Variety Name Hindi -->
                        <div class="form-group">
                            <label class="form-label">Variety Name (Hindi - हिन्दी)</label>
                            <input type="text" name="variety_name_hi" x-model="varietyForm.variety_name_hi" class="form-input" placeholder="किस्म का नाम">
                        </div>

                        <!-- Base Price -->
                        <div class="form-group">
                            <label class="form-label">Base Price (₹) *</label>
                            <input type="number" step="0.01" name="base_price" x-model="varietyForm.base_price" class="form-input" required>
                        </div>

                        <!-- 100% Alpine.js Packet Unit Selector -->
                        <div class="form-group">
                            <label class="form-label">Packet Unit *</label>
                            <input type="hidden" name="packet_size" :value="varietyForm.packet_size">
                            <div class="alpine-select-wrapper full-width" x-data="{ open: false }" @click.outside="open = false">
                                <div class="alpine-select-trigger" :class="{ 'active': open }" @click="open = !open">
                                    <span x-text="getPacketLabel(varietyForm.packet_size)"></span>
                                    <i class="ph ph-caret-down"></i>
                                </div>
                                <div class="alpine-select-menu" x-show="open" x-cloak x-transition>
                                    <div class="alpine-select-option" @click="varietyForm.packet_size = 'per_kg'; open = false;">Per Kg</div>
                                    <div class="alpine-select-option" @click="varietyForm.packet_size = 'per_450g_packet'; open = false;">Per 450g Packet</div>
                                    <div class="alpine-select-option" @click="varietyForm.packet_size = 'per_5kg_bag'; open = false;">Per 5kg Bag</div>
                                    <div class="alpine-select-option" @click="varietyForm.packet_size = 'per_10kg_bag'; open = false;">Per 10kg Bag</div>
                                    <div class="alpine-select-option" @click="varietyForm.packet_size = 'per_25kg_bag'; open = false;">Per 25kg Bag</div>
                                </div>
                            </div>
                        </div>

                        <!-- Stock Quantity & All Regions -->
                        <div class="form-group">
                            <label class="form-label">Stock Quantity (Packets)</label>
                            <input type="number" name="stock_quantity" x-model="varietyForm.stock_quantity" class="form-input">
                        </div>

                        <div class="form-group" style="margin-top:24px;">
                            <label style="display:flex; align-items:center; gap:8px; cursor:pointer; font-size:0.86rem; font-weight:600;">
                                <input type="checkbox" name="is_all_regions" x-model="varietyForm.is_all_regions" value="1"> Available in All Regions
                            </label>
                        </div>

                        <!-- Yield & Duration -->
                        <div class="form-group">
                            <label class="form-label">Average Yield (Quintals/Acre)</label>
                            <input type="number" step="0.1" name="average_yield" x-model="varietyForm.average_yield" class="form-input" placeholder="e.g. 28.5">
                        </div>

                        <div class="form-group">
                            <label class="form-label">Growth Duration (Days)</label>
                            <input type="number" name="growth_duration" x-model="varietyForm.growth_duration" class="form-input" placeholder="e.g. 135">
                        </div>

                        <!-- Recommended Regions (Multilingual) -->
                        <div class="form-group full" style="border-top: 1px solid var(--border); padding-top: 12px; margin-top: 4px;">
                            <label class="form-label" style="display:flex; justify-content:space-between; align-items:center;">
                                <span><i class="ph-bold ph-map-pin" style="color:var(--primary);"></i> Recommended Regions (English)</span>
                                <button type="button" @click="autoTranslateRegions()" class="btn-translate" :disabled="isTranslating">
                                    <i class="ph-bold" :class="isTranslating ? 'ph-spinner-gap spin' : 'ph-translate'"></i>
                                    <span x-text="isTranslating ? 'Translating...' : 'Auto-Translate Regions'"></span>
                                </button>
                            </label>
                            <input type="text" name="region_en" x-model="varietyForm.region_en" class="form-input" placeholder="e.g. Nalgonda, Warangal, Khammam">
                            <input type="hidden" name="region" :value="varietyForm.region_te || varietyForm.region_en || varietyForm.region">
                        </div>

                        <div class="form-group">
                            <label class="form-label">Regions (Telugu - తెలుగు)</label>
                            <input type="text" name="region_te" x-model="varietyForm.region_te" class="form-input" placeholder="e.g. నల్గొండ, వరంగల్, ఖమ్మం">
                        </div>

                        <div class="form-group">
                            <label class="form-label">Regions (Hindi - हिन्दी)</label>
                            <input type="text" name="region_hi" x-model="varietyForm.region_hi" class="form-input" placeholder="e.g. नलगोंडा, वारंगल, खम्मम">
                        </div>

                        <!-- Sowing Period (Multilingual) -->
                        <div class="form-group full" style="border-top: 1px solid var(--border); padding-top: 12px; margin-top: 4px;">
                            <label class="form-label" style="display:flex; justify-content:space-between; align-items:center;">
                                <span><i class="ph-bold ph-calendar" style="color:var(--primary);"></i> Sowing Period (English)</span>
                                <button type="button" @click="autoTranslateSowing()" class="btn-translate" :disabled="isTranslating">
                                    <i class="ph-bold" :class="isTranslating ? 'ph-spinner-gap spin' : 'ph-translate'"></i>
                                    <span x-text="isTranslating ? 'Translating...' : 'Auto-Translate Sowing'"></span>
                                </button>
                            </label>
                            <input type="text" name="sowing_period_en" x-model="varietyForm.sowing_period_en" class="form-input" placeholder="e.g. June - July (Kharif)">
                            <input type="hidden" name="sowing_period" :value="varietyForm.sowing_period_te || varietyForm.sowing_period_en || varietyForm.sowing_period">
                        </div>

                        <div class="form-group">
                            <label class="form-label">Sowing Period (Telugu - తెలుగు)</label>
                            <input type="text" name="sowing_period_te" x-model="varietyForm.sowing_period_te" class="form-input" placeholder="e.g. జూన్ - జూలై (ఖరీఫ్)">
                        </div>

                        <div class="form-group">
                            <label class="form-label">Sowing Period (Hindi - हिन्दी)</label>
                            <input type="text" name="sowing_period_hi" x-model="varietyForm.sowing_period_hi" class="form-input" placeholder="e.g. जून - जुलाई (खरीफ)">
                        </div>

                        <!-- Variety Image -->
                        <div class="form-group full">
                            <label class="form-label">Variety Image</label>
                            <div class="media-upload-card" :class="{ 'dragover': dragOver }"
                                 x-data="mediaUploader({ uploadType: 'seeds', isVideo: false })"
                                 x-init="url = varietyForm.image_url || ''; $watch('varietyForm.image_url', val => url = val || ''); $watch('url', val => varietyForm.image_url = val)"
                                 @dragover.prevent="dragOver = true" @dragleave.prevent="dragOver = false" @drop.prevent="dragOver = false; upload($event.dataTransfer.files[0])">
                                <div class="media-input-row">
                                    <template x-if="url">
                                        <div class="media-preview-thumb">
                                            <img :src="url" alt="Preview">
                                            <button type="button" class="media-clear-btn" @click="clear()" title="Remove">&times;</button>
                                        </div>
                                    </template>
                                    <template x-if="!url">
                                        <div class="media-preview-placeholder">
                                            <i class="ph ph-image"></i>
                                        </div>
                                    </template>
                                    <input type="text" name="image_url" x-model="url" class="form-input media-url-input" placeholder="Paste image URL or click Upload...">
                                    <input type="file" x-ref="fileInput" style="display:none;" accept="image/*" @change="upload($event.target.files[0]); $event.target.value=''">
                                    <button type="button" class="btn-upload" @click="$refs.fileInput.click()" :disabled="isUploading">
                                        <i class="ph-bold" :class="isUploading ? 'ph-spinner-gap spin' : 'ph-cloud-arrow-up'"></i>
                                        <span x-text="isUploading ? progress + '%' : 'Upload Image'"></span>
                                    </button>
                                </div>
                                <div class="media-progress-bar-wrap" x-show="isUploading" x-cloak>
                                    <div class="media-progress-bar-fill" :style="'width: ' + progress + '%'"></div>
                                </div>
                                <div class="media-status-text" :class="statusType" x-show="statusText" x-cloak x-text="statusText"></div>
                            </div>
                        </div>

                        <!-- Testimonial Video -->
                        <div class="form-group full">
                            <label class="form-label">Testimonial Video (Optional)</label>
                            <div class="media-upload-card" :class="{ 'dragover': dragOver }"
                                 x-data="mediaUploader({ uploadType: 'videos', isVideo: true })"
                                 x-init="url = varietyForm.testimonial_video_url || ''; $watch('varietyForm.testimonial_video_url', val => url = val || ''); $watch('url', val => varietyForm.testimonial_video_url = val)"
                                 @dragover.prevent="dragOver = true" @dragleave.prevent="dragOver = false" @drop.prevent="dragOver = false; upload($event.dataTransfer.files[0])">
                                <div class="media-input-row">
                                    <template x-if="url">
                                        <div class="media-preview-thumb video-preview">
                                            <i class="ph-fill ph-video-camera"></i>
                                            <button type="button" class="media-clear-btn" @click="clear()" title="Remove">&times;</button>
                                        </div>
                                    </template>
                                    <template x-if="!url">
                                        <div class="media-preview-placeholder">
                                            <i class="ph ph-video"></i>
                                        </div>
                                    </template>
                                    <input type="text" name="testimonial_video_url" x-model="url" class="form-input media-url-input" placeholder="Paste video URL or click Upload MP4/WebM...">
                                    <input type="file" x-ref="fileInput" style="display:none;" accept="video/*" @change="upload($event.target.files[0]); $event.target.value=''">
                                    <button type="button" class="btn-upload" @click="$refs.fileInput.click()" :disabled="isUploading">
                                        <i class="ph-bold" :class="isUploading ? 'ph-spinner-gap spin' : 'ph-video-camera'"></i>
                                        <span x-text="isUploading ? progress + '%' : 'Upload Video'"></span>
                                    </button>
                                </div>
                                <div class="media-progress-bar-wrap" x-show="isUploading" x-cloak>
                                    <div class="media-progress-bar-fill" :style="'width: ' + progress + '%'"></div>
                                </div>
                                <div class="media-status-text" :class="statusType" x-show="statusText" x-cloak x-text="statusText"></div>
                            </div>
                        </div>

                        <!-- Multilingual Details with Auto-Translator -->
                        <div class="form-group full">
                            <label class="form-label">
                                Details / Agronomic Features (English)
                                <button type="button" @click="autoTranslateVariety()" class="btn-translate" :disabled="isTranslating">
                                    <i class="ph-bold" :class="isTranslating ? 'ph-spinner-gap spin' : 'ph-translate'"></i>
                                    <span x-text="isTranslating ? 'Translating...' : 'Auto-Translate Details'"></span>
                                </button>
                            </label>
                            <textarea name="details_en" x-model="varietyForm.details_en" class="form-textarea" placeholder="Key features, pest tolerance..."></textarea>
                        </div>

                        <div class="form-group">
                            <label class="form-label">Details (Telugu - తెలుగు)</label>
                            <textarea name="details_te" x-model="varietyForm.details_te" class="form-textarea" placeholder="లక్షణాలు, దిగుబడి వివరాలు..."></textarea>
                        </div>

                        <div class="form-group">
                            <label class="form-label">Details (Hindi - हिन्दी)</label>
                            <textarea name="details_hi" x-model="varietyForm.details_hi" class="form-textarea" placeholder="विवरण..."></textarea>
                        </div>

                    </div>
                </div>

                <div class="modal-footer">
                    <button type="button" @click="showVarietyModal = false" class="btn btn-secondary">Cancel</button>
                    <button type="submit" class="btn btn-primary">Save Seed Variety</button>
                </div>
            </form>
        </div>
    </div>

    <!-- ============================================================== -->
    <!-- MODAL: ADD / EDIT CATEGORY (3 LANGUAGES + AUTO-TRANSLATOR) -->
    <!-- ============================================================== -->
    <div class="modal-overlay" x-show="showCategoryModal" x-cloak @click.self="showCategoryModal = false">
        <div class="modal-container" style="max-width: 540px;">
            <div class="modal-header">
                <h3 x-text="categoryForm.id > 0 ? 'Edit Product Category #' + categoryForm.id : 'Add New Product Category'"></h3>
                <button type="button" @click="showCategoryModal = false" style="background:none; border:none; font-size:1.4rem; cursor:pointer;">&times;</button>
            </div>
            <form method="POST">
                <input type="hidden" name="action" value="save_category">
                <input type="hidden" name="category_id" :value="categoryForm.id">
                <input type="hidden" name="old_category_name_te" :value="categoryForm.old_te">
                <input type="hidden" name="old_category_name_en" :value="categoryForm.old_en">

                <div class="modal-body">
                    <!-- English with Auto-Translator -->
                    <div class="form-group">
                        <label class="form-label">
                            Category Name (English) *
                            <button type="button" @click="autoTranslateCategory()" class="btn-translate" :disabled="isTranslating">
                                <i class="ph-bold" :class="isTranslating ? 'ph-spinner-gap spin' : 'ph-translate'"></i>
                                <span x-text="isTranslating ? 'Translating...' : 'Auto-Translate to Telugu & Hindi'"></span>
                            </button>
                        </label>
                        <input type="text" name="category_name_en" x-model="categoryForm.name_en" class="form-input" placeholder="e.g. Farm Machinery" required>
                    </div>

                    <!-- Telugu -->
                    <div class="form-group">
                        <label class="form-label">Category Name (Telugu - తెలుగు) *</label>
                        <input type="text" name="category_name_te" x-model="categoryForm.name_te" class="form-input" placeholder="e.g. వ్యవసాయ యంత్రాలు" required>
                    </div>

                    <!-- Hindi -->
                    <div class="form-group">
                        <label class="form-label">Category Name (Hindi - हिन्दी)</label>
                        <input type="text" name="category_name_hi" x-model="categoryForm.name_hi" class="form-input" placeholder="e.g. कृषि मशीनरी">
                    </div>

                    <span class="helper-text">Updating will synchronize all existing products associated with this category across all advertisers.</span>
                </div>
                <div class="modal-footer">
                    <button type="button" @click="showCategoryModal = false" class="btn btn-secondary">Cancel</button>
                    <button type="submit" class="btn btn-primary">Save Category</button>
                </div>
            </form>
        </div>
    </div>

    <!-- ============================================================== -->
    <!-- MODAL: ADD / EDIT CROP (MULTILINGUAL + AUTO-TRANSLATOR) -->
    <!-- ============================================================== -->
    <div class="modal-overlay" x-show="showCropModal" x-cloak @click.self="showCropModal = false">
        <div class="modal-container" style="max-width: 520px;">
            <div class="modal-header">
                <h3 x-text="cropForm.crop_id > 0 ? 'Edit Agricultural Crop' : 'Add New Agricultural Crop'"></h3>
                <button type="button" @click="showCropModal = false" style="background:none; border:none; font-size:1.4rem; cursor:pointer;">&times;</button>
            </div>
            <form method="POST" enctype="multipart/form-data">
                <input type="hidden" name="action" value="save_crop">
                <input type="hidden" name="crop_id" :value="cropForm.crop_id">

                <div class="modal-body">
                    <div class="form-group">
                        <label class="form-label">
                            Crop Name (English) *
                            <button type="button" @click="autoTranslateCrop()" class="btn-translate" :disabled="isTranslating">
                                <i class="ph-bold" :class="isTranslating ? 'ph-spinner-gap spin' : 'ph-translate'"></i>
                                <span x-text="isTranslating ? 'Translating...' : 'Auto-Translate'"></span>
                            </button>
                        </label>
                        <input type="text" name="name_en" x-model="cropForm.name_en" class="form-input" placeholder="e.g. Soyabean" required>
                    </div>
                    <div class="form-group">
                        <label class="form-label">Crop Name (Telugu - తెలుగు) *</label>
                        <input type="text" name="name" x-model="cropForm.name" class="form-input" placeholder="e.g. సోయాబీన్" required>
                    </div>
                    <div class="form-group">
                        <label class="form-label">Crop Name (Hindi - हिन्दी)</label>
                        <input type="text" name="name_hi" x-model="cropForm.name_hi" class="form-input" placeholder="e.g. सोयाबीन">
                    </div>
                    <div class="form-group">
                        <label class="form-label">Crop Icon / Image</label>
                        <div class="media-upload-card" :class="{ 'dragover': dragOver }"
                             x-data="mediaUploader({ uploadType: 'crops', isVideo: false })"
                             x-init="url = cropForm.image_url || ''; $watch('cropForm.image_url', val => url = val || ''); $watch('url', val => cropForm.image_url = val)"
                             @dragover.prevent="dragOver = true" @dragleave.prevent="dragOver = false" @drop.prevent="dragOver = false; upload($event.dataTransfer.files[0])">
                            <div class="media-input-row">
                                <template x-if="url">
                                    <div class="media-preview-thumb">
                                        <img :src="url" alt="Preview">
                                        <button type="button" class="media-clear-btn" @click="clear()" title="Remove">&times;</button>
                                    </div>
                                </template>
                                <template x-if="!url">
                                    <div class="media-preview-placeholder">
                                        <i class="ph ph-image"></i>
                                    </div>
                                </template>
                                <input type="text" name="image_url" x-model="url" class="form-input media-url-input" placeholder="Paste image URL or click Upload...">
                                <input type="file" x-ref="fileInput" style="display:none;" accept="image/*" @change="upload($event.target.files[0]); $event.target.value=''">
                                <button type="button" class="btn-upload" @click="$refs.fileInput.click()" :disabled="isUploading">
                                    <i class="ph-bold" :class="isUploading ? 'ph-spinner-gap spin' : 'ph-cloud-arrow-up'"></i>
                                    <span x-text="isUploading ? progress + '%' : 'Upload Image'"></span>
                                </button>
                            </div>
                            <div class="media-progress-bar-wrap" x-show="isUploading" x-cloak>
                                <div class="media-progress-bar-fill" :style="'width: ' + progress + '%'"></div>
                            </div>
                            <div class="media-status-text" :class="statusType" x-show="statusText" x-cloak x-text="statusText"></div>
                        </div>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" @click="showCropModal = false" class="btn btn-secondary">Cancel</button>
                    <button type="submit" class="btn btn-primary">Save Crop</button>
                </div>
            </form>
        </div>
    </div>

    <!-- ============================================================== -->
    <!-- MODAL: ADD ADVERTISER -->
    <!-- ============================================================== -->
    <div class="modal-overlay" x-show="showAdvertiserModal" x-cloak @click.self="showAdvertiserModal = false">
        <div class="modal-container" style="max-width: 480px;">
            <div class="modal-header">
                <h3>Add New Advertiser Partner</h3>
                <button type="button" @click="showAdvertiserModal = false" style="background:none; border:none; font-size:1.4rem; cursor:pointer;">&times;</button>
            </div>
            <form method="POST">
                <input type="hidden" name="action" value="save_advertiser">

                <div class="modal-body">
                    <div class="form-group">
                        <label class="form-label">Company / Advertiser Name *</label>
                        <input type="text" name="advertiser_name" class="form-input" placeholder="e.g. Coromandel Agri Corp" required>
                    </div>
                    <div class="form-group">
                        <label class="form-label">Advertiser Code (Optional)</label>
                        <input type="text" name="advertiser_code" class="form-input" placeholder="Auto-generated if empty">
                    </div>
                    <div class="form-group">
                        <label class="form-label">Email Address *</label>
                        <input type="email" name="email_address" class="form-input" placeholder="contact@company.com" required>
                    </div>
                    <div class="form-group">
                        <label class="form-label">Initial Password</label>
                        <input type="text" name="password" class="form-input" value="12345678">
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" @click="showAdvertiserModal = false" class="btn btn-secondary">Cancel</button>
                    <button type="submit" class="btn btn-primary">Add Advertiser</button>
                </div>
            </form>
        </div>
    </div>

    <!-- ============================================================== -->
    <!-- MODAL: ADD VENDOR -->
    <!-- ============================================================== -->
    <div class="modal-overlay" x-show="showVendorModal" x-cloak @click.self="showVendorModal = false">
        <div class="modal-container" style="max-width: 480px;">
            <div class="modal-header">
                <h3>Add Seed Vendor / Supplier</h3>
                <button type="button" @click="showVendorModal = false" style="background:none; border:none; font-size:1.4rem; cursor:pointer;">&times;</button>
            </div>
            <form method="POST">
                <input type="hidden" name="action" value="save_vendor">

                <div class="modal-body">
                    <div class="form-group">
                        <label class="form-label">Company / Vendor Name *</label>
                        <input type="text" name="company_name" x-model="vendorForm.company_name" class="form-input" placeholder="e.g. Kaveri Seeds Ltd" required>
                    </div>
                    <div class="form-group">
                        <label class="form-label">Contact Number *</label>
                        <input type="text" name="contact_number" x-model="vendorForm.contact_number" class="form-input" placeholder="e.g. 9876543210" required>
                    </div>
                    <div class="form-group">
                        <label class="form-label">Seed License Number</label>
                        <input type="text" name="license_number" x-model="vendorForm.license_number" class="form-input" placeholder="e.g. LIC-2026-TG01">
                    </div>
                    <div class="form-group full">
                        <label class="form-label">Vendor Logo</label>
                        <div class="media-upload-card" :class="{ 'dragover': dragOver }"
                             x-data="mediaUploader({ uploadType: 'vendors', isVideo: false })"
                             x-init="url = vendorForm.logo_url || ''; $watch('vendorForm.logo_url', val => url = val || ''); $watch('url', val => vendorForm.logo_url = val)"
                             @dragover.prevent="dragOver = true" @dragleave.prevent="dragOver = false" @drop.prevent="dragOver = false; upload($event.dataTransfer.files[0])">
                            <div class="media-input-row">
                                <template x-if="url">
                                    <div class="media-preview-thumb">
                                        <img :src="url" alt="Preview">
                                        <button type="button" class="media-clear-btn" @click="clear()" title="Remove">&times;</button>
                                    </div>
                                </template>
                                <template x-if="!url">
                                    <div class="media-preview-placeholder">
                                        <i class="ph ph-image"></i>
                                    </div>
                                </template>
                                <input type="text" name="logo_url" x-model="url" class="form-input media-url-input" placeholder="Paste image URL or click Upload...">
                                <input type="file" x-ref="fileInput" style="display:none;" accept="image/*" @change="upload($event.target.files[0]); $event.target.value=''">
                                <button type="button" class="btn-upload" @click="$refs.fileInput.click()" :disabled="isUploading">
                                    <i class="ph-bold" :class="isUploading ? 'ph-spinner-gap spin' : 'ph-cloud-arrow-up'"></i>
                                    <span x-text="isUploading ? progress + '%' : 'Upload Logo'"></span>
                                </button>
                            </div>
                            <div class="media-progress-bar-wrap" x-show="isUploading" x-cloak>
                                <div class="media-progress-bar-fill" :style="'width: ' + progress + '%'"></div>
                            </div>
                            <div class="media-status-text" :class="statusType" x-show="statusText" x-cloak x-text="statusText"></div>
                        </div>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" @click="showVendorModal = false" class="btn btn-secondary">Cancel</button>
                    <button type="submit" class="btn btn-primary">Add Vendor</button>
                </div>
            </form>
        </div>
    </div>

    <!-- Hidden form for deletions -->
    <form method="POST" id="deleteProductForm" style="display:none;">
        <input type="hidden" name="action" value="delete_product">
        <input type="hidden" name="product_id" id="deleteProductId">
    </form>
    <form method="POST" id="deleteVarietyForm" style="display:none;">
        <input type="hidden" name="action" value="delete_variety">
        <input type="hidden" name="variety_id" id="deleteVarietyId">
    </form>
    <form method="POST" id="deleteCategoryForm" style="display:none;">
        <input type="hidden" name="action" value="delete_category">
        <input type="hidden" name="category_id" id="deleteCategoryId">
    </form>
    <form method="POST" id="deleteCropForm" style="display:none;">
        <input type="hidden" name="action" value="delete_crop">
        <input type="hidden" name="crop_id" id="deleteCropId">
    </form>

    <!-- Alpine.js Application Logic -->
    <script>
        function mediaUploader(options) {
            return {
                uploadType: options.uploadType || 'products',
                isVideo: !!options.isVideo,
                url: '',
                isUploading: false,
                progress: 0,
                statusText: '',
                statusType: '',
                dragOver: false,

                upload(file) {
                    if (!file) return;
                    const self = this;
                    self.isUploading = true;
                    self.progress = 0;
                    self.statusText = 'Uploading...';
                    self.statusType = 'text-info';

                    const formData = new FormData();
                    formData.append('file', file);

                    const xhr = new XMLHttpRequest();
                    xhr.open('POST', 'shop_seeds_dashboard.php?ajax_upload=' + encodeURIComponent(self.uploadType), true);

                    xhr.upload.onprogress = function(e) {
                        if (e.lengthComputable) {
                            const percent = Math.round((e.loaded / e.total) * 100);
                            self.progress = percent;
                            self.statusText = 'Uploading (' + percent + '%)...';
                        }
                    };

                    xhr.onload = function() {
                        self.isUploading = false;
                        if (xhr.status >= 200 && xhr.status < 300) {
                            try {
                                const res = JSON.parse(xhr.responseText);
                                if (res.success && res.url) {
                                    self.url = res.url;
                                    self.progress = 100;
                                    self.statusText = 'Uploaded successfully!';
                                    self.statusType = 'text-success';
                                    setTimeout(() => { if (self.statusType === 'text-success') self.statusText = ''; }, 3500);
                                } else {
                                    self.statusText = res.error || 'Upload failed';
                                    self.statusType = 'text-danger';
                                }
                            } catch (err) {
                                self.statusText = 'Upload response error';
                                self.statusType = 'text-danger';
                            }
                        } else {
                            self.statusText = 'HTTP ' + xhr.status + ' error';
                            self.statusType = 'text-danger';
                        }
                    };

                    xhr.onerror = function() {
                        self.isUploading = false;
                        self.statusText = 'Network connection error';
                        self.statusType = 'text-danger';
                    };

                    xhr.send(formData);
                },

                clear() {
                    this.url = '';
                    this.progress = 0;
                    this.statusText = '';
                    this.statusType = '';
                }
            };
        }

        function catalogApp() {
            return {
                showProductModal: false,
                showVarietyModal: false,
                showCategoryModal: false,
                showCropModal: false,
                showAdvertiserModal: false,
                showVendorModal: false,

                // Lifecycle & Notification State
                toasts: [],
                toastSeq: 0,
                isTranslating: false,

                // Custom Confirm Dialog State (Zero Native Popups)
                confirmModal: {
                    show: false,
                    title: '',
                    message: '',
                    subtext: '',
                    confirmText: 'Confirm',
                    confirmClass: 'btn-danger',
                    icon: 'ph-trash',
                    iconColor: 'danger',
                    onConfirm: null,
                    loading: false
                },

                init() {
                    <?php if ($flash): ?>
                        this.showToast(<?= json_encode($flash['text']) ?>, <?= json_encode($flash['type'] === 'danger' ? 'danger' : 'success') ?>);
                    <?php endif; ?>
                },

                showToast(message, type = 'success', duration = 3800) {
                    const id = ++this.toastSeq;
                    this.toasts.push({ id, message, type });
                    if (duration > 0) {
                        setTimeout(() => {
                            this.removeToast(id);
                        }, duration);
                    }
                },

                removeToast(id) {
                    this.toasts = this.toasts.filter(t => t.id !== id);
                },

                askConfirm(options = {}) {
                    this.confirmModal = {
                        show: true,
                        title: options.title || 'Are you sure?',
                        message: options.message || '',
                        subtext: options.subtext || '',
                        confirmText: options.confirmText || 'Confirm',
                        confirmClass: options.confirmClass || 'btn-danger',
                        icon: options.icon || 'ph-warning',
                        iconColor: options.iconColor || 'danger',
                        onConfirm: options.onConfirm || null,
                        loading: false
                    };
                },

                closeConfirm() {
                    if (!this.confirmModal.loading) {
                        this.confirmModal.show = false;
                    }
                },

                async executeConfirm() {
                    if (typeof this.confirmModal.onConfirm === 'function') {
                        this.confirmModal.loading = true;
                        try {
                            await this.confirmModal.onConfirm();
                        } catch (err) {
                            console.error(err);
                            this.showToast('Action failed: ' + (err.message || 'Error occurred'), 'danger');
                        } finally {
                            this.confirmModal.loading = false;
                            this.confirmModal.show = false;
                        }
                    } else {
                        this.confirmModal.show = false;
                    }
                },

                // Lookup data
                advertisersList: <?= json_encode($advertisers) ?>,
                categoriesList: <?= json_encode($productCategories) ?>,
                cropsMasterList: <?= json_encode($cropsList) ?>,
                vendorsList: <?= json_encode($vendors) ?>,
                regionsList: <?= json_encode($regions) ?>,

                // Product Form
                productForm: {
                    product_id: 0,
                    advertiser_id: 1,
                    category: '',
                    category_en: '',
                    category_hi: '',
                    product_code: '',
                    region_id: '',
                    product_name_en: '',
                    product_name: '',
                    product_name_hi: '',
                    price: 0,
                    mrp: '',
                    in_stock: true,
                    is_active: true,
                    image_url_1: '',
                    image_url_2: '',
                    image_url_3: '',
                    product_video_url: '',
                    product_description_en: '',
                    product_description: '',
                    product_description_hi: ''
                },

                // Variety Form
                varietyForm: {
                    variety_id: 0,
                    crop_name: 'Rice',
                    vendor_id: 1,
                    variety_name_en: '',
                    variety_name_te: '',
                    variety_name_hi: '',
                    base_price: 100,
                    packet_size: 'per_kg',
                    stock_quantity: 100,
                    is_all_regions: true,
                    average_yield: '',
                    growth_duration: '',
                    region: '',
                    region_en: '',
                    region_te: '',
                    region_hi: '',
                    sowing_period: '',
                    sowing_period_en: '',
                    sowing_period_te: '',
                    sowing_period_hi: '',
                    image_url: '',
                    testimonial_video_url: '',
                    details_en: '',
                    details_te: '',
                    details_hi: ''
                },

                // Multilingual Category Form
                categoryForm: {
                    id: 0,
                    name_en: '',
                    name_te: '',
                    name_hi: '',
                    old_te: '',
                    old_en: ''
                },

                // Crop Form
                cropForm: {
                    crop_id: 0,
                    name_en: '',
                    name: '',
                    name_hi: '',
                    image_url: ''
                },

                // Vendor Form
                vendorForm: {
                    company_name: '',
                    contact_number: '',
                    license_number: '',
                    logo_url: ''
                },

                // Helpers for Dropdown Labels
                getAdvertiserName(id) {
                    const found = this.advertisersList.find(a => a.advertiser_id == id);
                    return found ? (found.advertiser_name + ' (' + found.advertiser_code + ')') : 'Select Advertiser';
                },

                getCategoryLabel(te, en) {
                    if (!te && !en) return 'Select Category';
                    const found = this.categoriesList.find(c => c.category_name_te === te || c.category_name_en === en);
                    return found ? (found.category_name_en + ' (' + found.category_name_te + ')') : (en || te);
                },

                selectCategory(cat) {
                    this.productForm.category = cat.category_name_te || cat.category_name_en;
                    this.productForm.category_en = cat.category_name_en || cat.category_name_te;
                    this.productForm.category_hi = cat.category_name_hi || '';
                },

                getRegionName(id) {
                    if (!id) return 'All Regions';
                    const found = this.regionsList.find(r => r.id == id);
                    return found ? found.region_name : 'All Regions';
                },

                getVendorName(id) {
                    const found = this.vendorsList.find(v => v.id == id);
                    return found ? found.company_name : 'Select Vendor';
                },

                getPacketLabel(code) {
                    const map = {
                        'per_kg': 'Per Kg',
                        'per_450g_packet': 'Per 450g Packet',
                        'per_5kg_bag': 'Per 5kg Bag',
                        'per_10kg_bag': 'Per 10kg Bag',
                        'per_25kg_bag': 'Per 25kg Bag'
                    };
                    return map[code] || (code || 'Select Unit');
                },

                // Product Modals
                openProductModal() {
                    const defaultAdv = this.advertisersList.length > 0 ? this.advertisersList[0].advertiser_id : 1;
                    const defaultCat = this.categoriesList.length > 0 ? this.categoriesList[0] : null;

                    this.productForm = {
                        product_id: 0,
                        advertiser_id: defaultAdv,
                        category: defaultCat ? (defaultCat.category_name_te || defaultCat.category_name_en) : 'General',
                        category_en: defaultCat ? (defaultCat.category_name_en || defaultCat.category_name_te) : 'General',
                        category_hi: defaultCat ? (defaultCat.category_name_hi || '') : '',
                        product_code: '',
                        region_id: '',
                        product_name_en: '',
                        product_name: '',
                        product_name_hi: '',
                        price: '',
                        mrp: '',
                        in_stock: true,
                        is_active: true,
                        image_url_1: '',
                        image_url_2: '',
                        image_url_3: '',
                        product_video_url: '',
                        product_description_en: '',
                        product_description: '',
                        product_description_hi: ''
                    };
                    this.showProductModal = true;
                },

                editProduct(p) {
                    let catTe = p.category || '';
                    let catEn = p.category_en || '';
                    let catHi = p.category_hi || '';

                    const match = this.categoriesList.find(c => 
                        (catTe && (c.category_name_te === catTe || c.category_name_en === catTe)) ||
                        (catEn && (c.category_name_en === catEn || c.category_name_te === catEn))
                    );
                    if (match) {
                        catTe = match.category_name_te || catTe;
                        catEn = match.category_name_en || catEn;
                        catHi = match.category_name_hi || catHi;
                    }

                    this.productForm = {
                        product_id: p.product_id,
                        advertiser_id: p.advertiser_id,
                        category: catTe,
                        category_en: catEn,
                        category_hi: catHi,
                        product_code: p.product_code || '',
                        region_id: p.region_id || '',
                        product_name_en: p.product_name_en || p.product_name,
                        product_name: p.product_name || '',
                        product_name_hi: p.product_name_hi || '',
                        price: p.price,
                        mrp: p.mrp || '',
                        in_stock: parseInt(p.in_stock) === 1,
                        is_active: parseInt(p.is_active) === 1,
                        image_url_1: p.image_url_1 || '',
                        image_url_2: p.image_url_2 || '',
                        image_url_3: p.image_url_3 || '',
                        product_video_url: p.product_video_url || '',
                        product_description_en: p.product_description_en || p.product_description,
                        product_description: p.product_description || '',
                        product_description_hi: p.product_description_hi || ''
                    };
                    this.showProductModal = true;
                },

                confirmDeleteProduct(id, name) {
                    this.askConfirm({
                        title: 'Delete Product',
                        message: `Are you sure you want to delete product "${name}" (ID #${id})?`,
                        subtext: 'This will permanently remove the product and its associated customer enquiries.',
                        confirmText: 'Delete Product',
                        confirmClass: 'btn-danger',
                        icon: 'ph-trash',
                        iconColor: 'danger',
                        onConfirm: () => {
                            document.getElementById('deleteProductId').value = id;
                            document.getElementById('deleteProductForm').submit();
                        }
                    });
                },

                confirmBulkProducts() {
                    const checkedBoxes = document.querySelectorAll('input[name="selected_products[]"]:checked');
                    if (!checkedBoxes || checkedBoxes.length === 0) {
                        this.showToast('Please select at least one product using the checkboxes.', 'warning');
                        return;
                    }
                    this.askConfirm({
                        title: 'Apply Bulk Action',
                        message: `Apply selected bulk action to ${checkedBoxes.length} selected product(s)?`,
                        subtext: 'The selected operation will be executed immediately on all chosen items.',
                        confirmText: 'Apply Action',
                        confirmClass: 'btn-primary',
                        icon: 'ph-check-circle',
                        iconColor: 'info',
                        onConfirm: () => {
                            document.getElementById('bulkProductsForm').submit();
                        }
                    });
                },

                confirmSyncCategories() {
                    this.askConfirm({
                        title: 'Synchronize Categories',
                        message: 'Synchronize all products with the latest multilingual category names?',
                        subtext: 'This updates English, Telugu, and Hindi category columns across all matching products in the catalog.',
                        confirmText: 'Sync Now',
                        confirmClass: 'btn-primary',
                        icon: 'ph-arrows-clockwise',
                        iconColor: 'info',
                        onConfirm: () => {
                            document.getElementById('syncCategoriesForm').submit();
                        }
                    });
                },

                async toggleProductStock(productId, inStock) {
                    try {
                        const fd = new FormData();
                        fd.append('ajax_action', 'toggle_product_stock');
                        fd.append('product_id', productId);
                        fd.append('in_stock', inStock ? 1 : 0);
                        await fetch('shop_seeds_dashboard.php', { method: 'POST', body: fd });
                    } catch (e) { console.error(e); }
                },

                async toggleProductActive(productId, isActive) {
                    try {
                        const fd = new FormData();
                        fd.append('ajax_action', 'toggle_product_active');
                        fd.append('product_id', productId);
                        fd.append('is_active', isActive ? 1 : 0);
                        await fetch('shop_seeds_dashboard.php', { method: 'POST', body: fd });
                    } catch (e) { console.error(e); }
                },

                // Variety Modals
                openVarietyModal() {
                    const defaultVen = this.vendorsList.length > 0 ? this.vendorsList[0].id : 1;
                    const defaultCrop = this.cropsMasterList.length > 0 ? (this.cropsMasterList[0].name_en || this.cropsMasterList[0].name) : 'Rice';

                    this.varietyForm = {
                        variety_id: 0,
                        crop_name: defaultCrop,
                        vendor_id: defaultVen,
                        variety_name_en: '',
                        variety_name_te: '',
                        variety_name_hi: '',
                        base_price: 100,
                        packet_size: 'per_kg',
                        stock_quantity: 100,
                        is_all_regions: true,
                        average_yield: '',
                        growth_duration: '',
                        region: '',
                        region_en: '',
                        region_te: '',
                        region_hi: '',
                        sowing_period: '',
                        sowing_period_en: '',
                        sowing_period_te: '',
                        sowing_period_hi: '',
                        image_url: '',
                        testimonial_video_url: '',
                        details_en: '',
                        details_te: '',
                        details_hi: ''
                    };
                    this.showVarietyModal = true;
                },

                editVariety(v) {
                    const isAscii = str => /^[A-Za-z0-9 ,.\/-]+$/.test(str || '');
                    let regEn = v.region_en || '';
                    let regTe = v.region_te || '';
                    let regHi = v.region_hi || '';
                    if (!regEn && !regTe && v.region) {
                        if (isAscii(v.region)) { regEn = v.region; } else { regTe = v.region; }
                    }

                    let sowEn = v.sowing_period_en || '';
                    let sowTe = v.sowing_period_te || '';
                    let sowHi = v.sowing_period_hi || '';
                    if (!sowEn && !sowTe && v.sowing_period) {
                        if (isAscii(v.sowing_period)) { sowEn = v.sowing_period; } else { sowTe = v.sowing_period; }
                    }

                    this.varietyForm = {
                        variety_id: v.id,
                        crop_name: v.crop_name,
                        vendor_id: v.vendor_id || 1,
                        variety_name_en: v.variety_name_en || '',
                        variety_name_te: v.variety_name_te || '',
                        variety_name_hi: v.variety_name_hi || '',
                        base_price: v.base_price || 0,
                        packet_size: v.packet_size || 'per_kg',
                        stock_quantity: v.stock_quantity ?? 100,
                        is_all_regions: parseInt(v.is_all_regions) === 1,
                        average_yield: v.average_yield || '',
                        growth_duration: v.growth_duration || '',
                        region: v.region || '',
                        region_en: regEn,
                        region_te: regTe,
                        region_hi: regHi,
                        sowing_period: v.sowing_period || '',
                        sowing_period_en: sowEn,
                        sowing_period_te: sowTe,
                        sowing_period_hi: sowHi,
                        image_url: v.image_url || '',
                        testimonial_video_url: v.testimonial_video_url || '',
                        details_en: v.details_en || '',
                        details_te: v.details_te || '',
                        details_hi: v.details_hi || ''
                    };
                    this.showVarietyModal = true;
                },

                confirmDeleteVariety(id, name) {
                    this.askConfirm({
                        title: 'Delete Seed Variety',
                        message: `Are you sure you want to delete seed variety "${name}" (ID #${id})?`,
                        subtext: 'This will also remove linked vendor listings and farmer bookings associated with this variety.',
                        confirmText: 'Delete Variety',
                        confirmClass: 'btn-danger',
                        icon: 'ph-trash',
                        iconColor: 'danger',
                        onConfirm: () => {
                            document.getElementById('deleteVarietyId').value = id;
                            document.getElementById('deleteVarietyForm').submit();
                        }
                    });
                },

                // Category Modals (Multilingual)
                openCreateCategoryModal() {
                    this.categoryForm = { id: 0, name_en: '', name_te: '', name_hi: '', old_te: '', old_en: '' };
                    this.showCategoryModal = true;
                },

                editCategory(c) {
                    this.categoryForm = {
                        id: c.id,
                        name_en: c.category_name_en,
                        name_te: c.category_name_te,
                        name_hi: c.category_name_hi || '',
                        old_te: c.category_name_te,
                        old_en: c.category_name_en
                    };
                    this.showCategoryModal = true;
                },

                confirmDeleteCategory(id, name) {
                    this.askConfirm({
                        title: 'Delete Category',
                        message: `Delete category "${name}" from master list?`,
                        subtext: 'Products currently categorized under this will retain their names in the database.',
                        confirmText: 'Delete Category',
                        confirmClass: 'btn-danger',
                        icon: 'ph-tag',
                        iconColor: 'danger',
                        onConfirm: () => {
                            document.getElementById('deleteCategoryId').value = id;
                            document.getElementById('deleteCategoryForm').submit();
                        }
                    });
                },

                // Crops Master Modals
                openCropModal() {
                    this.cropForm = { crop_id: 0, name_en: '', name: '', name_hi: '', image_url: '' };
                    this.showCropModal = true;
                },

                editCrop(c) {
                    this.cropForm = {
                        crop_id: c.id,
                        name_en: c.name_en || '',
                        name: c.name || '',
                        name_hi: c.name_hi || '',
                        image_url: c.image_url || ''
                    };
                    this.showCropModal = true;
                },

                confirmDeleteCrop(id, name) {
                    this.askConfirm({
                        title: 'Delete Master Crop',
                        message: `Delete crop "${name}" from master database?`,
                        subtext: 'Existing seed varieties referencing this crop will remain untouched.',
                        confirmText: 'Delete Crop',
                        confirmClass: 'btn-danger',
                        icon: 'ph-plant',
                        iconColor: 'danger',
                        onConfirm: () => {
                            document.getElementById('deleteCropId').value = id;
                            document.getElementById('deleteCropForm').submit();
                        }
                    });
                },

                openAdvertiserModal() { this.showAdvertiserModal = true; },
                openVendorModal() {
                    this.vendorForm = { company_name: '', contact_number: '', license_number: '', logo_url: '' };
                    this.showVendorModal = true;
                },

                // ==========================================
                // INBUILT AUTO-TRANSLATOR (IN EVERY PLACE - INSTANT & PRODUCTION GRADE)
                // ==========================================
                async autoTranslateCategory() {
                    const text = this.categoryForm.name_en;
                    if (!text || !text.trim()) {
                        this.showToast('Please enter English Category Name first.', 'warning');
                        return;
                    }
                    this.isTranslating = true;
                    try {
                        const fd = new FormData();
                        fd.append('source_lang', 'en');
                        fd.append('name', text.trim());
                        const res = await fetch('shop_seeds_dashboard.php?ajax_translate=1', { method: 'POST', body: fd });
                        const json = await res.json();
                        if (json.success) {
                            if (json.name_te) this.categoryForm.name_te = json.name_te;
                            if (json.name_hi) this.categoryForm.name_hi = json.name_hi;
                            this.showToast('Category translated to Telugu & Hindi successfully!', 'success');
                        } else {
                            this.showToast('Translation error: ' + (json.error || 'Failed'), 'danger');
                        }
                    } catch (e) {
                        console.error(e);
                        this.showToast('Translation request failed. Please try again.', 'danger');
                    } finally {
                        this.isTranslating = false;
                    }
                },

                async autoTranslateCrop() {
                    const text = this.cropForm.name_en;
                    if (!text || !text.trim()) {
                        this.showToast('Please enter English Crop Name first.', 'warning');
                        return;
                    }
                    this.isTranslating = true;
                    try {
                        const fd = new FormData();
                        fd.append('source_lang', 'en');
                        fd.append('name', text.trim());
                        const res = await fetch('shop_seeds_dashboard.php?ajax_translate=1', { method: 'POST', body: fd });
                        const json = await res.json();
                        if (json.success) {
                            if (json.name_te) this.cropForm.name = json.name_te;
                            if (json.name_hi) this.cropForm.name_hi = json.name_hi;
                            this.showToast('Crop name translated to Telugu & Hindi!', 'success');
                        } else {
                            this.showToast('Translation error: ' + (json.error || 'Failed'), 'danger');
                        }
                    } catch (e) {
                        console.error(e);
                        this.showToast('Translation request failed.', 'danger');
                    } finally {
                        this.isTranslating = false;
                    }
                },

                async autoTranslateProduct() {
                    const name = this.productForm.product_name_en;
                    const desc = this.productForm.product_description_en;
                    if ((!name || !name.trim()) && (!desc || !desc.trim())) {
                        this.showToast('Please enter English Product Name or Description first.', 'warning');
                        return;
                    }
                    this.isTranslating = true;
                    try {
                        const fd = new FormData();
                        fd.append('source_lang', 'en');
                        if (name) fd.append('name', name.trim());
                        if (desc) fd.append('desc', desc.trim());
                        const res = await fetch('shop_seeds_dashboard.php?ajax_translate=1', { method: 'POST', body: fd });
                        const json = await res.json();
                        if (json.success) {
                            if (json.name_te) this.productForm.product_name = json.name_te;
                            if (json.name_hi) this.productForm.product_name_hi = json.name_hi;
                            if (json.desc_te) this.productForm.product_description = json.desc_te;
                            if (json.desc_hi) this.productForm.product_description_hi = json.desc_hi;
                            this.showToast('Product translated to Telugu & Hindi!', 'success');
                        } else {
                            this.showToast('Translation error: ' + (json.error || 'Failed'), 'danger');
                        }
                    } catch (e) {
                        console.error(e);
                        this.showToast('Translation request failed.', 'danger');
                    } finally {
                        this.isTranslating = false;
                    }
                },

                async autoTranslateVariety() {
                    const name = this.varietyForm.variety_name_en;
                    const desc = this.varietyForm.details_en;
                    const region = this.varietyForm.region_en;
                    const sowing = this.varietyForm.sowing_period_en;
                    if ((!name || !name.trim()) && (!desc || !desc.trim()) && (!region || !region.trim()) && (!sowing || !sowing.trim())) {
                        this.showToast('Please enter English Variety Name, Details, Regions, or Sowing Period first.', 'warning');
                        return;
                    }
                    this.isTranslating = true;
                    try {
                        const fd = new FormData();
                        fd.append('source_lang', 'en');
                        if (name) fd.append('name', name.trim());
                        if (desc) fd.append('desc', desc.trim());
                        if (region) fd.append('region', region.trim());
                        if (sowing) fd.append('sowing', sowing.trim());
                        const res = await fetch('shop_seeds_dashboard.php?ajax_translate=1', { method: 'POST', body: fd });
                        const json = await res.json();
                        if (json.success) {
                            if (json.name_te) this.varietyForm.variety_name_te = json.name_te;
                            if (json.name_hi) this.varietyForm.variety_name_hi = json.name_hi;
                            if (json.desc_te) this.varietyForm.details_te = json.desc_te;
                            if (json.desc_hi) this.varietyForm.details_hi = json.desc_hi;
                            if (json.region_te) this.varietyForm.region_te = json.region_te;
                            if (json.region_hi) this.varietyForm.region_hi = json.region_hi;
                            if (json.sowing_te) this.varietyForm.sowing_period_te = json.sowing_te;
                            if (json.sowing_hi) this.varietyForm.sowing_period_hi = json.sowing_hi;
                            this.showToast('Seed variety details translated to Telugu & Hindi!', 'success');
                        } else {
                            this.showToast('Translation error: ' + (json.error || 'Failed'), 'danger');
                        }
                    } catch (e) {
                        console.error(e);
                        this.showToast('Translation request failed.', 'danger');
                    } finally {
                        this.isTranslating = false;
                    }
                },

                async autoTranslateRegions() {
                    const region = this.varietyForm.region_en;
                    if (!region || !region.trim()) {
                        this.showToast('Please enter English Recommended Regions first.', 'warning');
                        return;
                    }
                    this.isTranslating = true;
                    try {
                        const fd = new FormData();
                        fd.append('source_lang', 'en');
                        fd.append('region', region.trim());
                        const res = await fetch('shop_seeds_dashboard.php?ajax_translate=1', { method: 'POST', body: fd });
                        const json = await res.json();
                        if (json.success) {
                            if (json.region_te) this.varietyForm.region_te = json.region_te;
                            if (json.region_hi) this.varietyForm.region_hi = json.region_hi;
                            this.showToast('Regions translated to Telugu & Hindi!', 'success');
                        } else {
                            this.showToast('Translation error: ' + (json.error || 'Failed'), 'danger');
                        }
                    } catch (e) {
                        console.error(e);
                        this.showToast('Translation request failed.', 'danger');
                    } finally {
                        this.isTranslating = false;
                    }
                },

                async autoTranslateSowing() {
                    const sowing = this.varietyForm.sowing_period_en;
                    if (!sowing || !sowing.trim()) {
                        this.showToast('Please enter English Sowing Period first.', 'warning');
                        return;
                    }
                    this.isTranslating = true;
                    try {
                        const fd = new FormData();
                        fd.append('source_lang', 'en');
                        fd.append('sowing', sowing.trim());
                        const res = await fetch('shop_seeds_dashboard.php?ajax_translate=1', { method: 'POST', body: fd });
                        const json = await res.json();
                        if (json.success) {
                            if (json.sowing_te) this.varietyForm.sowing_period_te = json.sowing_te;
                            if (json.sowing_hi) this.varietyForm.sowing_period_hi = json.sowing_hi;
                            this.showToast('Sowing period translated to Telugu & Hindi!', 'success');
                        } else {
                            this.showToast('Translation error: ' + (json.error || 'Failed'), 'danger');
                        }
                    } catch (e) {
                        console.error(e);
                        this.showToast('Translation request failed.', 'danger');
                    } finally {
                        this.isTranslating = false;
                    }
                },

                toggleSelectAll(event, checkboxName) {
                    const cbs = document.getElementsByName(checkboxName);
                    for (let cb of cbs) {
                        cb.checked = event.target.checked;
                    }
                }
            };
        }
    </script>
</body>
</html>
