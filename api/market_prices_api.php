<?php
// market_prices_api.php
//
// Market prices (data.gov.in "mandi" dataset) - REAL DATA ONLY.
// No seed / fabricated rows are ever returned or stored by this file.
//
// Configuration (never hardcode secrets here):
// Each value is read from getenv(), then $_SERVER, then $_ENV, then a PHP constant of the same name:
//   DATA_GOV_IN_API_KEY  data.gov.in API key (never echoed)
//   MARKET_SYNC_TOKEN    enables the web `sync_market_prices` action; must be sent in the X-Sync-Token header only
//   MARKET_SHOW_LEGACY   set to 1 to ALSO serve pre-fix rows labelled source='legacy' (possibly fabricated).
//                        Default: hidden. Only for installs that have not yet run database/cleanup_fake_market_prices.sql.
//
// Secrets file: if api/market_secrets.php exists (git-ignored; see market_secrets.example.php) it is loaded
// here so both the web API and the cron script pick up DATA_GOV_IN_API_KEY without touching config.php.
if (file_exists(__DIR__ . '/market_secrets.php')) {
    require_once __DIR__ . '/market_secrets.php';
}

// This file only defines functions (safe to require_once from CLI scripts).

// ---------------------------------------------------------------------------
// Schema self-heal
// ---------------------------------------------------------------------------

function mpEnsureIndex($pdo, $indexName, $columnsSql) {
    // $indexName / $columnsSql are internal constants (never user input).
    try {
        $stmt = $pdo->query("SHOW INDEX FROM `market_prices_history` WHERE Key_name = '" . $indexName . "'");
        $exists = $stmt && $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$exists) {
            $pdo->exec("ALTER TABLE `market_prices_history` ADD INDEX `" . $indexName . "` (" . $columnsSql . ")");
        }
    } catch (Throwable $e) {}
}

function ensureMarketPricesTable($pdo) {
    static $done = false;
    if ($done) return;
    $done = true;
    // NOTE: `grade` is deliberately NOT part of uniq_entry (changing a unique key on a live table is risky), so two
    // grades of the same variety in the same market on the same day collapse into one row (last upstream row wins).
    try {
        $pdo->exec("CREATE TABLE IF NOT EXISTS `market_prices_history` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `state` VARCHAR(100) NOT NULL,
            `district` VARCHAR(100) NOT NULL,
            `market` VARCHAR(150) NOT NULL,
            `commodity` VARCHAR(150) NOT NULL,
            `variety` VARCHAR(100) DEFAULT 'Other',
            `grade` VARCHAR(50) DEFAULT 'FAQ',
            `arrival_date` DATE NOT NULL,
            `min_price` DECIMAL(10,2) DEFAULT 0,
            `max_price` DECIMAL(10,2) DEFAULT 0,
            `modal_price` DECIMAL(10,2) DEFAULT 0,
            `source` VARCHAR(16) NOT NULL DEFAULT 'gov',
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY `uniq_entry` (`state`, `district`, `market`, `commodity`, `variety`, `arrival_date`),
            INDEX `idx_state_dist` (`state`, `district`),
            INDEX `idx_comm_date` (`commodity`, `arrival_date`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");
    } catch (Throwable $e) {}

    // Add `source` only if missing. Pre-existing rows are labelled 'legacy' (unverified,
    // written before this fix); the column default is then switched to 'gov'.
    try {
        $col = $pdo->query("SHOW COLUMNS FROM `market_prices_history` LIKE 'source'");
        $hasSource = $col && $col->fetch(PDO::FETCH_ASSOC);
        if (!$hasSource) {
            $pdo->exec("ALTER TABLE `market_prices_history` ADD COLUMN `source` VARCHAR(16) NOT NULL DEFAULT 'legacy'");
            $pdo->exec("ALTER TABLE `market_prices_history` ALTER COLUMN `source` SET DEFAULT 'gov'");
        }
    } catch (Throwable $e) {}

    mpEnsureIndex($pdo, 'idx_state_date', '`state`, `arrival_date`');
    mpEnsureIndex($pdo, 'idx_state_comm_date', '`state`, `commodity`, `arrival_date`');

    try {
        $pdo->exec("CREATE TABLE IF NOT EXISTS `market_sync_log` (
            `state` VARCHAR(100) NOT NULL PRIMARY KEY,
            `last_attempt` DATETIME NOT NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");
    } catch (Throwable $e) {}
}

function resolveCommodityImageUrl($commodity) {
    if (empty($commodity)) return '';
    $raw = trim((string)$commodity);
    $lower = mb_strtolower($raw, 'UTF-8');

    // 1. High-priority exact and alias matches (English, Hindi transliteration, Telugu script)
    // Paddy / Rice
    if (strpos($lower, 'paddy') !== false || strpos($lower, 'rice') !== false || strpos($lower, 'dhan') !== false || strpos($lower, 'వరి') !== false || strpos($lower, 'ధాన్యం') !== false || strpos($lower, 'బియ్యం') !== false || strpos($lower, 'धान') !== false || strpos($lower, 'चावल') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Rice.png';
    }
    // Bhindi / Ladies Finger / Okra
    if (strpos($lower, 'bhindi') !== false || strpos($lower, 'ladies finger') !== false || strpos($lower, 'okra') !== false || strpos($lower, 'lady') !== false || strpos($lower, 'బెండకాయ') !== false || strpos($lower, 'भिंडी') !== false) {
        return 'https://kiosk.cropsync.in/crops/okra.jpg';
    }
    // Chilli
    if (strpos($lower, 'chilli') !== false || strpos($lower, 'chili') !== false || strpos($lower, 'mirchi') !== false || strpos($lower, 'మిర్చి') !== false || strpos($lower, 'మిరప') !== false || strpos($lower, 'मिर्च') !== false) {
        return 'https://kiosk.cropsync.in/crops/chilli.jpg';
    }
    // Bitter Gourd
    if (strpos($lower, 'bitter gourd') !== false || strpos($lower, 'karela') !== false || strpos($lower, 'కాకరకాయ') !== false || strpos($lower, 'करेला') !== false) {
        return 'https://kiosk.cropsync.in/crops/bitter_gourd.jpg';
    }
    // Other Gourds
    if (strpos($lower, 'ridgeguard') !== false || strpos($lower, 'ridge gourd') !== false || strpos($lower, 'tori') !== false || strpos($lower, 'kundru') !== false || strpos($lower, 'little gourd') !== false || strpos($lower, 'bottle gourd') !== false || strpos($lower, 'lauki') !== false || strpos($lower, 'బీరకాయ') !== false || strpos($lower, 'సొరకాయ') !== false || strpos($lower, 'लौकी') !== false || strpos($lower, 'तोरई') !== false) {
        return 'https://kiosk.cropsync.in/crops/bitter_gourd.jpg';
    }
    // Sugarcane / Jaggery
    if (strpos($lower, 'gur') !== false || strpos($lower, 'jaggery') !== false || strpos($lower, 'sugarcane') !== false || strpos($lower, 'ganna') !== false || strpos($lower, 'చెరకు') !== false || strpos($lower, 'బెల్లం') !== false || strpos($lower, 'गन्ना') !== false) {
        return 'https://kiosk.cropsync.in/crops/sugarcane.jpg';
    }
    // Sunflower
    if (strpos($lower, 'sunflower') !== false || strpos($lower, 'surajmukhi') !== false || strpos($lower, 'పొద్దుతిరుగుడు') !== false || strpos($lower, 'सूरजमुखी') !== false) {
        return 'https://kiosk.cropsync.in/crops/sunflower.jpg';
    }
    // Cumin / Jeera
    if (strpos($lower, 'cumin') !== false || strpos($lower, 'jeera') !== false || strpos($lower, 'జీలకర్ర') !== false || strpos($lower, 'जीरा') !== false) {
        return 'https://kiosk.cropsync.in/crops/cumin.jpg';
    }
    // Tea
    if (strpos($lower, 'tea') !== false || strpos($lower, 'chai') !== false || strpos($lower, 'టీ') !== false || strpos($lower, 'చాయ్') !== false || strpos($lower, 'चाय') !== false) {
        return 'https://kiosk.cropsync.in/crops/tea.jpg';
    }
    // Cotton
    if (strpos($lower, 'cotton') !== false || strpos($lower, 'kapas') !== false || strpos($lower, 'పత్తి') !== false || strpos($lower, 'కపాస్') !== false || strpos($lower, 'कपास') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Cotton.png';
    }
    // Maize / Corn / Jowar / Sorghum
    if (strpos($lower, 'maize') !== false || strpos($lower, 'corn') !== false || strpos($lower, 'jowar') !== false || strpos($lower, 'sorghum') !== false || strpos($lower, 'మొక్కజొన్న') !== false || strpos($lower, 'జొన్నలు') !== false || strpos($lower, 'మక్క') !== false || strpos($lower, 'मक्का') !== false || strpos($lower, 'ज्वार') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Maize.png';
    }
    // Wheat / Millets
    if (strpos($lower, 'wheat') !== false || strpos($lower, 'gehun') !== false || strpos($lower, 'bajra') !== false || strpos($lower, 'ragi') !== false || strpos($lower, 'barley') !== false || strpos($lower, 'గోధుమలు') !== false || strpos($lower, 'సజ్జలు') !== false || strpos($lower, 'రాగులు') !== false || strpos($lower, 'గేహూ') !== false || strpos($lower, 'गेहूं') !== false || strpos($lower, 'बाजरा') !== false || strpos($lower, 'रागी') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Wheat.png';
    }
    // Groundnut / Peanut
    if (strpos($lower, 'groundnut') !== false || strpos($lower, 'peanut') !== false || strpos($lower, 'moongphali') !== false || strpos($lower, 'వేరుశనగ') !== false || strpos($lower, 'పల్లీ') !== false || strpos($lower, 'मूंगफली') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Groundnut.png';
    }
    // Turmeric
    if (strpos($lower, 'turmeric') !== false || strpos($lower, 'haldi') !== false || strpos($lower, 'పసుపు') !== false || strpos($lower, 'हल्दी') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Turmeric.png';
    }
    // Pulses & Legumes (Bengal gram, red gram, green gram, urd, soyabean, cowpea, etc.)
    if (strpos($lower, 'soyabean') !== false || strpos($lower, 'soybean') !== false || strpos($lower, 'gram') !== false || strpos($lower, 'chana') !== false || strpos($lower, 'arhar') !== false || preg_match('/\btur\b/u', $lower) || strpos($lower, 'moong') !== false || strpos($lower, 'urd') !== false || strpos($lower, 'bean') !== false || strpos($lower, 'pulse') !== false || strpos($lower, 'lobia') !== false || strpos($lower, 'శనగలు') !== false || strpos($lower, 'కందులు') !== false || strpos($lower, 'పెసలు') !== false || strpos($lower, 'మినుములు') !== false || strpos($lower, 'సోయాబీన్') !== false || strpos($lower, 'అలసందలు') !== false || strpos($lower, 'ఉలవలు') !== false || strpos($lower, 'चना') !== false || strpos($lower, 'अरहर') !== false || strpos($lower, 'तूर') !== false || strpos($lower, 'मूंग') !== false || strpos($lower, 'उड़द') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Soyabean.png';
    }
    // Lime / Mousambi / Sweet Lime
    if (strpos($lower, 'mousambi') !== false || strpos($lower, 'sweet lime') !== false || strpos($lower, 'lime') !== false || strpos($lower, 'mosambi') !== false || strpos($lower, 'బత్తాయి') !== false || strpos($lower, 'मौसमी') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Lime.png';
    }
    // Lemon
    if (strpos($lower, 'lemon') !== false || strpos($lower, 'nimbu') !== false || strpos($lower, 'నిమ్మకాయ') !== false || strpos($lower, 'నీంబూ') !== false || strpos($lower, 'नींबू') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Lemon.png';
    }
    // Sesame / Linseed
    if (strpos($lower, 'sesamum') !== false || strpos($lower, 'sesame') !== false || strpos($lower, 'til') !== false || strpos($lower, 'linseed') !== false || strpos($lower, 'alsi') !== false || strpos($lower, 'నువ్వులు') !== false || strpos($lower, 'ఆముదం') !== false || strpos($lower, 'तिल') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Linseed.png';
    }
    // Mustard
    if (strpos($lower, 'mustard') !== false || strpos($lower, 'sarson') !== false || strpos($lower, 'rai') !== false || strpos($lower, 'ఆవాలు') !== false || strpos($lower, 'सरसों') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Mustard.png';
    }
    // Safflower
    if (strpos($lower, 'safflower') !== false || strpos($lower, 'kusuma') !== false || strpos($lower, 'కుసుమ') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Safflower.png';
    }
    // Tobacco
    if (strpos($lower, 'tobacco') !== false || strpos($lower, 'పొగాకు') !== false || strpos($lower, 'तंबाकू') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Tobacco.png';
    }
    // Tomato
    if (strpos($lower, 'tomato') !== false || strpos($lower, 'టమోటా') !== false || strpos($lower, 'టమాట') !== false || strpos($lower, 'टमाटर') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Tomato.png';
    }
    // Onion
    if (strpos($lower, 'onion') !== false || strpos($lower, 'pyaj') !== false || strpos($lower, 'ఉల్లిపాయ') !== false || strpos($lower, 'ఉల్లి') !== false || strpos($lower, 'प्याज') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Onion.png';
    }
    // Potato
    if (strpos($lower, 'potato') !== false || strpos($lower, 'aloo') !== false || strpos($lower, 'బంగాళాదుంప') !== false || strpos($lower, 'ఆలూ') !== false || strpos($lower, 'आलू') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Potato.png';
    }
    // Brinjal
    if (strpos($lower, 'brinjal') !== false || strpos($lower, 'eggplant') !== false || strpos($lower, 'baingan') !== false || strpos($lower, 'వంకాయ') !== false || strpos($lower, 'बैंगन') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Brinjal.png';
    }
    // Cabbage
    if (strpos($lower, 'cabbage') !== false || strpos($lower, 'క్యాబేజీ') !== false || strpos($lower, 'पत्तागोभी') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Cabbage.png';
    }
    // Cauliflower
    if (strpos($lower, 'cauliflower') !== false || strpos($lower, 'కాలీఫ్లవర్') !== false || strpos($lower, 'फूलगोभी') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Cauliflower.png';
    }
    // Carrot
    if (strpos($lower, 'carrot') !== false || strpos($lower, 'క్యారెట్') !== false || strpos($lower, 'गाजर') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Carrot.png';
    }
    // Capsicum
    if (strpos($lower, 'capsicum') !== false || strpos($lower, 'క్యాప్సికమ్') !== false || strpos($lower, 'शिमला मिर्च') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Capsicum.png';
    }
    // Banana
    if (strpos($lower, 'banana') !== false || strpos($lower, 'అరటి') !== false || strpos($lower, 'केला') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Banana.png';
    }
    // Mango
    if (strpos($lower, 'mango') !== false || strpos($lower, 'మామిడి') !== false || strpos($lower, 'आम') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Mango.png';
    }
    // Apple
    if (strpos($lower, 'apple') !== false || strpos($lower, 'ఆపిల్') !== false || strpos($lower, 'సేబు') !== false || strpos($lower, 'सेब') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Apple.png';
    }
    // Orange
    if (strpos($lower, 'orange') !== false || strpos($lower, 'నారింజ') !== false || strpos($lower, 'संतरा') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Orange.png';
    }
    // Guava
    if (strpos($lower, 'guava') !== false || strpos($lower, 'జామకాయ') !== false || strpos($lower, 'अमरूद') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Guava.png';
    }
    // Grapes
    if (strpos($lower, 'grapes') !== false || strpos($lower, 'ద్రాక్ష') !== false || strpos($lower, 'अंगूर') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Grapes.png';
    }
    // Papaya
    if (strpos($lower, 'papaya') !== false || strpos($lower, 'బొప్పాయి') !== false || strpos($lower, 'पपीता') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Papaya.png';
    }
    // Pomegranate
    if (strpos($lower, 'pomegranate') !== false || strpos($lower, 'దానిమ్మ') !== false || strpos($lower, 'अनार') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Pomegranate.png';
    }
    // Pineapple
    if (strpos($lower, 'pineapple') !== false || strpos($lower, 'అనానస్') !== false || strpos($lower, 'अनानास') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Pineapple.png';
    }
    // Drumstick
    if (strpos($lower, 'drumstick') !== false || strpos($lower, 'మునగకాయ') !== false || strpos($lower, 'सहजन') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Drumstick.png';
    }
    // Garlic / Ginger
    if (strpos($lower, 'garlic') !== false || strpos($lower, 'ginger') !== false || strpos($lower, 'వెల్లుల్లి') !== false || strpos($lower, 'అల్లం') !== false || strpos($lower, 'लहसुन') !== false || strpos($lower, 'अदरक') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Garlic.png';
    }
    // Beetroot
    if (strpos($lower, 'beetroot') !== false || strpos($lower, 'బీట్‌రూట్') !== false || strpos($lower, 'चुकंदर') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Beetroot.png';
    }
    // Avocado
    if (strpos($lower, 'avocado') !== false || strpos($lower, 'వెన్నపండు') !== false || strpos($lower, 'एवोकैडो') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Avocado.png';
    }
    // Pumpkin / Watermelon
    if (strpos($lower, 'pumpkin') !== false || strpos($lower, 'watermelon') !== false || strpos($lower, 'melon') !== false || strpos($lower, 'పుచ్చకాయ') !== false || strpos($lower, 'గుమ్మడికాయ') !== false || strpos($lower, 'तरबूज') !== false || strpos($lower, 'कद्दू') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Pumpkin.png';
    }
    // Spinach / Coriander
    if (strpos($lower, 'spinach') !== false || strpos($lower, 'coriander') !== false || strpos($lower, 'కొత్తిమీర') !== false || strpos($lower, 'పాలకూర') !== false || strpos($lower, 'धनिया') !== false || strpos($lower, 'पालक') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Spinach.png';
    }
    // Wood
    if (strpos($lower, 'wood') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Wood.png';
    }
    // Fish
    if (strpos($lower, 'fish') !== false || strpos($lower, 'చేప') !== false || strpos($lower, 'मछली') !== false) {
        return 'https://kiosk.cropsync.in/api/commodity/Fish.png';
    }

    // Default clean
    $cleaned = preg_replace('/\s*\(.*?\)\s*/', ' ', $raw);
    $cleaned = preg_replace('/[^a-zA-Z0-9\s]/', '', $cleaned);
    $words = array_filter(explode(' ', trim($cleaned)));
    $pascal = '';
    foreach ($words as $w) {
        $pascal .= ucfirst(strtolower($w));
    }
    if (!empty($pascal)) {
        return "https://kiosk.cropsync.in/api/commodity/{$pascal}.png";
    }
    return 'https://kiosk.cropsync.in/assets/images/logo.png';
}

// ---------------------------------------------------------------------------
// Configuration + small helpers
// ---------------------------------------------------------------------------

// Config value: getenv(), then $_SERVER (shared hosting often exposes SetEnv only there), then $_ENV, then a constant.
// Returns '' when unset. Callers must never echo the result.
function mpConfigValue($name) {
    $v = getenv($name);
    if (is_string($v) && trim($v) !== '') return trim($v);
    foreach ([$_SERVER, $_ENV] as $bag) {
        foreach ([$name, 'REDIRECT_' . $name] as $k) {
            if (isset($bag[$k]) && is_string($bag[$k]) && trim($bag[$k]) !== '') return trim($bag[$k]);
        }
    }
    if (defined($name)) {
        $c = constant($name);
        if (is_scalar($c) && trim((string)$c) !== '') return trim((string)$c);
    }
    return '';
}

function mpGetApiKey() {
    return mpConfigValue('DATA_GOV_IN_API_KEY');
}

function mpShowLegacy() {
    static $v = null;
    if ($v === null) {
        $v = in_array(strtolower(mpConfigValue('MARKET_SHOW_LEGACY')), ['1', 'true', 'yes', 'on'], true);
    }
    return $v;
}

// Shared read filter: only verified upstream rows (source = 'gov'; NULL/legacy are hidden) unless MARKET_SHOW_LEGACY=1.
// Returns an SQL fragment starting with " AND " (or '').
function mpSourceClause($column = 'source') {
    return mpShowLegacy() ? '' : " AND $column = 'gov'";
}

function mpNormalizeText($s) {
    $s = mb_strtolower(trim((string)$s), 'UTF-8');
    $s = str_replace('&', ' and ', $s);
    $s = preg_replace('/[^\p{L}\p{N}\p{M}]+/u', ' ', $s);
    $s = preg_replace('/\s+/u', ' ', $s);
    return trim($s);
}

function mpIsAscii($s) {
    return $s !== '' && preg_match('/^[\x20-\x7e]+$/', $s) === 1;
}

function mpLikeEscape($s) {
    return addcslashes($s, "%_\\");
}

function mpValidYmd($s) {
    if (!is_string($s) || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $s)) return false;
    $d = DateTime::createFromFormat('!Y-m-d', $s);
    return $d && $d->format('Y-m-d') === $s;
}

// ---------------------------------------------------------------------------
// State normalisation
// ---------------------------------------------------------------------------

// canonical name => aliases (English spellings + Telugu/Hindi script names)
function mpStateAliasData() {
    return [
        'Andaman and Nicobar' => ['andaman nicobar', 'andaman and nicobar islands'],
        'Andhra Pradesh' => ['andhra', 'ap', 'andhrapradesh', 'ఆంధ్ర ప్రదేశ్', 'ఆంధ్రప్రదేశ్', 'आंध्र प्रदेश', 'आंध्रप्रदेश'],
        'Arunachal Pradesh' => ['arunachalpradesh'],
        'Assam' => [],
        'Bihar' => ['बिहार', 'బీహార్', 'బిహార్'],
        'Chandigarh' => [],
        'Chhattisgarh' => ['chattisgarh', 'chhatisgarh', 'chattishgarh', 'chhattishgarh', 'छत्तीसगढ़', 'छत्तीसगढ', 'ఛత్తీస్‌గఢ్', 'చత్తీస్‌గఢ్', 'ఛత్తీస్గఢ్'],
        'Dadra and Nagar Haveli' => ['dadra nagar haveli'],
        'Daman and Diu' => ['daman diu'],
        'Goa' => [],
        'Gujarat' => ['गुजरात', 'గుజరాత్'],
        'Haryana' => ['हरियाणा', 'హర్యానా'],
        'Himachal Pradesh' => ['himachalpradesh'],
        'Jammu and Kashmir' => ['jammu kashmir', 'jk'],
        'Jharkhand' => [],
        'Karnataka' => ['कर्नाटक', 'కర్ణాటక', 'कर्नाटका'],
        'Kerala' => ['केरल', 'केरला', 'కేరళ', 'కేరళా'],
        'Ladakh' => [],
        'Lakshadweep' => [],
        'Madhya Pradesh' => ['mp', 'madhyapradesh', 'मध्य प्रदेश', 'मध्यप्रदेश', 'మధ్య ప్రదేశ్', 'మధ్యప్రదేశ్'],
        'Maharashtra' => ['महाराष्ट्र', 'మహారాష్ట్ర'],
        'Manipur' => [],
        'Meghalaya' => [],
        'Mizoram' => [],
        'Nagaland' => [],
        'NCT of Delhi' => ['delhi', 'new delhi', 'nct delhi', 'national capital territory of delhi', 'दिल्ली', 'ఢిల్లీ', 'ఢిల్లి'],
        'Odisha' => ['orissa', 'ओडिशा', 'उड़ीसा', 'ఒడిశా', 'ఒడిషా'],
        'Puducherry' => ['pondicherry', 'pondichery', 'puduchery'],
        'Punjab' => ['पंजाब', 'పంజాబ్'],
        'Rajasthan' => ['राजस्थान', 'రాజస్థాన్'],
        'Sikkim' => [],
        'Tamil Nadu' => ['tamilnadu', 'tamil nadu', 'तमिलनाडु', 'தமிழ்நாடு', 'తమిళనాడు'],
        'Telangana' => ['telengana', 'telagana', 'telangna', 'ts', 'తెలంగాణ', 'తెలంగాణా', 'तेलंगाना', 'तेलंगाणा'],
        'Tripura' => [],
        'Uttar Pradesh' => ['up', 'uttarpradesh', 'उत्तर प्रदेश', 'उत्तरप्रदेश', 'ఉత్తర ప్రదేశ్', 'ఉత్తరప్రదేశ్'],
        'Uttarakhand' => ['uttaranchal', 'uttrakhand', 'उत्तराखंड', 'उत्तराखण्ड', 'ఉత్తరాఖండ్'],
        'West Bengal' => ['westbengal', 'bengal', 'पश्चिम बंगाल', 'పశ్చిమ బెంగాల్', 'పశ్చిమ బంగాళ్'],
    ];
}

// Spellings data.gov.in may use for a state (tried in order after the canonical name).
function mpStateUpstreamAlternates() {
    return [
        'Chhattisgarh' => ['Chattisgarh'],
        'Uttarakhand' => ['Uttrakhand'],
        'NCT of Delhi' => ['Delhi'],
        'Andaman and Nicobar' => ['Andaman and Nicobar Islands'],
        'Puducherry' => ['Pondicherry'],
    ];
}

function mpAllStates() {
    return array_keys(mpStateAliasData());
}

function mpStateLookupMap() {
    static $map = null;
    if ($map !== null) return $map;
    $map = [];
    foreach (mpStateAliasData() as $canon => $aliases) {
        $all = array_merge([$canon], $aliases, mpStateUpstreamAlternates()[$canon] ?? []);
        foreach ($all as $a) {
            $n = mpNormalizeText($a);
            if ($n === '') continue;
            $map[$n] = $canon;
            $map[str_replace(' ', '', $n)] = $canon;
        }
    }
    return $map;
}

// ---- Fuzzy matching helpers (shared by state and district resolution) ----

// Words that distinguish otherwise similar place names; never fuzzy-match across them.
function mpDirectionWords() {
    return ['north', 'south', 'east', 'west', 'central', 'urban', 'rural', 'city', 'new', 'old'];
}

// True when a token that differs between the two normalised names is a direction/type word.
function mpDiffHasDirectionWord($a, $b) {
    $ta = array_filter(explode(' ', $a), 'strlen');
    $tb = array_filter(explode(' ', $b), 'strlen');
    $diff = array_merge(array_diff($ta, $tb), array_diff($tb, $ta));
    foreach ($diff as $t) {
        if (in_array($t, mpDirectionWords(), true)) return true;
    }
    return false;
}

// Max edit distance: 1 when the shorter name has < 9 chars, else 2.
function mpFuzzyMaxDist($a, $b) {
    return min(strlen($a), strlen($b)) < 9 ? 1 : 2;
}

// $map: normalisedKey => value. Returns the value of the UNIQUE closest key within the allowed distance, or null
// (no candidate, or two different values tie).
function mpFuzzyUnique($n, $map) {
    if (!mpIsAscii($n)) return null;
    $bestD = PHP_INT_MAX;
    $vals = [];
    foreach ($map as $key => $val) {
        $key = (string)$key;
        if (!mpIsAscii($key)) continue;
        if (abs(strlen($key) - strlen($n)) > 2) continue;
        $d = levenshtein($n, $key);
        if ($d > mpFuzzyMaxDist($n, $key)) continue;
        if (mpDiffHasDirectionWord($n, $key)) continue;
        if ($d < $bestD) {
            $bestD = $d;
            $vals = [$val];
        } elseif ($d === $bestD && !in_array($val, $vals, true)) {
            $vals[] = $val;
        }
    }
    return count($vals) === 1 ? $vals[0] : null;
}

// Canonical state for a user supplied string (alias, script name, small typo). Unknown input is returned trimmed.
function mpCanonicalState($input) {
    $input = trim((string)$input);
    if ($input === '') return '';
    $map = mpStateLookupMap();
    $n = mpNormalizeText($input);
    if (isset($map[$n])) return $map[$n];
    $compact = str_replace(' ', '', $n);
    if (isset($map[$compact])) return $map[$compact];

    if (mpIsAscii($n) && strlen($n) >= 5) {
        $best = mpFuzzyUnique($n, $map);
        if ($best !== null) return $best;
    }
    return $input;
}

function mpResolveState($pdo, $input) {
    return mpCanonicalState($input);
}

// Spellings to match with `state IN (...)` (index friendly; the column collation is case-insensitive and
// PAD SPACE, so case and trailing-space differences match anyway). Each spelling is also given in lower case and
// with one leading space, so rows stored with sloppy casing/whitespace still match before the normalising UPDATE
// in database/market_prices_fix.sql has been run.
function mpStateVariants($canonical) {
    $canonical = trim((string)$canonical);
    $names = [$canonical];
    $data = mpStateAliasData();
    if (isset($data[$canonical])) {
        foreach (array_merge($data[$canonical], mpStateUpstreamAlternates()[$canonical] ?? []) as $a) {
            $names[] = trim($a);
        }
    }
    $out = [];
    foreach ($names as $n) {
        if ($n === '') continue;
        $lower = mb_strtolower($n, 'UTF-8');
        $out[] = $n;
        $out[] = $lower;
        $out[] = ' ' . $n;
        $out[] = ' ' . $lower;
    }
    return array_values(array_unique($out));
}

// state IN (...) plus the shared source filter. Safe to append " AND ..." to.
function mpStateWhere($variants, $column = 'state') {
    $ph = implode(',', array_fill(0, count($variants), '?'));
    return ["$column IN ($ph)" . mpSourceClause(), array_values($variants)];
}

// ---------------------------------------------------------------------------
// District normalisation / matching
// ---------------------------------------------------------------------------

function mpDistrictAliasGroups() {
    return [
        ['chittoor', 'chittor'],
        ['rangareddy', 'ranga reddy', 'rangareddi', 'ranga reddi', 'k v rangareddy'],
        ['medchal malkajgiri', 'medchal', 'malkajgiri', 'medchalmalkajgiri', 'medchal-malkajgiri', 'medchal–malkajgiri', 'medchal—malkajgiri', 'medchal malkajgiri district'],
        ['warangal urban', 'hanumakonda', 'hanamkonda', 'warangal'],
        ['tirupati', 'tirupathi'],
        ['visakhapatnam', 'vizag', 'vishakhapatnam', 'visakhapatanam', 'vishakapatnam', 'vishakhapatanam'],
        ['mahabubnagar', 'mahbubnagar', 'mahaboobnagar', 'mahabub nagar', 'mahbub nagar'],
        ['karimnagar', 'karim nagar'],
        ['nizamabad', 'nizambad'],
        ['east godavari', 'e godavari'],
        ['west godavari', 'w godavari'],
        ['ysr kadapa', 'y s r kadapa', 'kadapa', 'cuddapah'],
        ['nellore', 'spsr nellore', 'sri potti sriramulu nellore'],
        ['bhadradri kothagudem', 'kothagudem', 'bhadradri'],
        ['jayashankar bhupalpally', 'bhupalpally', 'jayashankar'],
        ['jogulamba gadwal', 'gadwal'],
        ['komaram bheem asifabad', 'asifabad', 'komaram bheem'],
        ['yadadri bhuvanagiri', 'yadadri', 'bhuvanagiri'],
        ['sangareddy', 'sanga reddy'],
        ['bengaluru urban', 'bangalore urban', 'bengaluru', 'bangalore'],
        ['mysuru', 'mysore'],
        ['belagavi', 'belgaum'],
        ['kalaburagi', 'gulbarga'],
        ['mumbai', 'bombay'],
        ['pune', 'poona'],
        ['gurugram', 'gurgaon'],
        ['prayagraj', 'allahabad'],
        ['ayodhya', 'faizabad'],
        ['kolkata', 'calcutta'],
        ['chennai', 'madras'],
        ['thiruvananthapuram', 'trivandrum'],
        ['ernakulam', 'kochi', 'cochin'],
    ];
}

// Normalised name + all alias-group siblings (the name itself first).
function mpDistrictCandidates($norm) {
    $cands = [$norm];
    $compact = str_replace(' ', '', $norm);
    foreach (mpDistrictAliasGroups() as $group) {
        $group = array_values(array_unique(array_filter(array_map('mpNormalizeText', $group), 'strlen')));
        $hit = false;
        foreach ($group as $g) {
            if ($g === $norm || str_replace(' ', '', $g) === $compact) { $hit = true; break; }
        }
        if ($hit) {
            foreach ($group as $g) $cands[] = $g;
        }
    }
    return array_values(array_unique($cands));
}

// Districts present in the DB for a state: [['district'=>..., 'count'=>n], ...]
function mpListStateDistricts($pdo, $variants) {
    static $cache = [];
    $ck = implode('|', $variants);
    if (isset($cache[$ck])) return $cache[$ck];
    list($where, $params) = mpStateWhere($variants);
    $rows = [];
    try {
        $stmt = $pdo->prepare("SELECT district, COUNT(*) AS c FROM market_prices_history WHERE $where AND district <> '' GROUP BY district ORDER BY c DESC, district ASC");
        $stmt->execute($params);
        foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $r) {
            $rows[] = ['district' => $r['district'], 'count' => (int)$r['c']];
        }
    } catch (Throwable $e) {}
    $cache[$ck] = $rows;
    return $rows;
}

// True when $needle occurs in $hay on whole-word boundaries (both already normalised, single-space separated).
function mpContainsWords($hay, $needle) {
    if ($needle === '') return false;
    return strpos(' ' . $hay . ' ', ' ' . $needle . ' ') !== false;
}

// Resolve a user district against the DB districts of the state. Returns the DB spelling or null.
function mpResolveDistrict($pdo, $variants, $input) {
    $n = mpNormalizeText($input);
    if ($n === '') return null;
    $list = mpListStateDistricts($pdo, $variants);
    if (empty($list)) return null;

    $dbNorm = [];
    foreach ($list as $row) {
        $dbNorm[$row['district']] = mpNormalizeText($row['district']);
    }

    // 1) exact / alias-group match (input's own spelling first)
    foreach (mpDistrictCandidates($n) as $cand) {
        $candCompact = str_replace(' ', '', $cand);
        foreach ($dbNorm as $orig => $dn) {
            if ($dn === $cand || str_replace(' ', '', $dn) === $candCompact) return $orig;
        }
    }

    // 2) whole-word 'contains' match: the contained name must be >= 5 chars and sit on word boundaries.
    //    The closest-length candidate must be unique, otherwise no match.
    $byNorm = [];
    foreach ($dbNorm as $orig => $dn) {
        if ($dn !== '' && !isset($byNorm[$dn])) $byNorm[$dn] = $orig;   // first (most rows) spelling wins
    }
    $bestDiff = PHP_INT_MAX;
    $bestSet = [];
    foreach ($byNorm as $dn => $orig) {
        $dn = (string)$dn;
        $short = mb_strlen($dn, 'UTF-8') <= mb_strlen($n, 'UTF-8') ? $dn : $n;
        if (mb_strlen($short, 'UTF-8') < 5) continue;
        if (mpContainsWords($dn, $n) || mpContainsWords($n, $dn)) {
            $diff = abs(mb_strlen($dn, 'UTF-8') - mb_strlen($n, 'UTF-8'));
            if ($diff < $bestDiff) { $bestDiff = $diff; $bestSet = [$orig]; }
            elseif ($diff === $bestDiff) { $bestSet[] = $orig; }
        }
    }
    if (count($bestSet) === 1) return $bestSet[0];
    if (count($bestSet) > 1) return null;

    // 3) fuzzy (ASCII only; <=1 edit for short names, <=2 for long; never across direction/type words; unique best)
    if (mpIsAscii($n) && strlen($n) >= 4) {
        $best = mpFuzzyUnique($n, $byNorm);
        if ($best !== null) return $best;
    }
    return null;
}


// ---------------------------------------------------------------------------
// Upstream (data.gov.in) fetch + normalise
// ---------------------------------------------------------------------------

function mpJsonOut($payload) {
    echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
}

function mpParsePrice($v) {
    $v = str_replace(',', '', trim((string)$v));
    if ($v === '' || !is_numeric($v)) return null;
    $f = (float)$v;
    return $f >= 0 ? $f : null;
}

// Accepts d/m/Y (upstream format), Y-m-d and d-m-Y. Returns 'Y-m-d' or null if invalid.
function mpParseDate($v) {
    $v = trim((string)$v);
    if ($v === '') return null;
    foreach (['!d/m/Y', '!Y-m-d', '!d-m-Y'] as $fmt) {
        $d = DateTime::createFromFormat($fmt, $v);
        if (!$d) continue;
        $err = DateTime::getLastErrors();
        if ($err && (($err['warning_count'] ?? 0) > 0 || ($err['error_count'] ?? 0) > 0)) continue;
        $ymd = $d->format('Y-m-d');
        if ($ymd < '2000-01-01' || $ymd > date('Y-m-d', strtotime('+2 days'))) return null;
        return $ymd;
    }
    return null;
}

// Tolerates key-casing variants (Min_Price / min_price / Min_x0020_Price ...). Returns null for unusable rows.
function mpNormalizeGovRecord($r) {
    if (!is_array($r)) return null;
    $k = array_change_key_case($r, CASE_LOWER);
    $pick = function ($names) use ($k) {
        foreach ($names as $n) {
            if (isset($k[$n]) && trim((string)$k[$n]) !== '') return trim((string)$k[$n]);
        }
        return '';
    };

    $district = $pick(['district']);
    $market = $pick(['market']);
    $commodity = $pick(['commodity']);
    if ($district === '' || $market === '' || $commodity === '') return null;

    $date = mpParseDate($pick(['arrival_date', 'arrivaldate']));
    if ($date === null) return null;

    $min = mpParsePrice($pick(['min_price', 'min_x0020_price', 'minprice']));
    $max = mpParsePrice($pick(['max_price', 'max_x0020_price', 'maxprice']));
    $modal = mpParsePrice($pick(['modal_price', 'modal_x0020_price', 'modalprice']));
    // Any absurd value (column is DECIMAL(10,2)) drops the row so one bad record cannot fail a whole batch.
    foreach ([$min, $max, $modal] as $pv) {
        if ($pv !== null && ($pv < 0 || $pv > 99999999)) return null;
    }
    if ($modal === null && $min !== null && $max !== null) $modal = ($min + $max) / 2;
    if ($modal === null || $modal <= 0) return null;
    if ($min === null) $min = $modal;
    if ($max === null) $max = $modal;
    if ($min > $max) { $t = $min; $min = $max; $max = $t; }

    $variety = $pick(['variety']);
    $grade = $pick(['grade']);

    return [
        'state' => mb_substr($pick(['state']), 0, 100, 'UTF-8'),
        'district' => mb_substr($district, 0, 100, 'UTF-8'),
        'market' => mb_substr($market, 0, 100, 'UTF-8'),
        'commodity' => mb_substr($commodity, 0, 100, 'UTF-8'),
        'variety' => mb_substr($variety !== '' ? $variety : 'Other', 0, 100, 'UTF-8'),
        'grade' => mb_substr($grade !== '' ? $grade : 'FAQ', 0, 50, 'UTF-8'),
        'arrival_date' => $date,
        'min_price' => $min,
        'max_price' => $max,
        'modal_price' => $modal,
    ];
}

// One upstream page. Returns ['ok'=>bool, 'records'=>[], 'total'=>int|null, 'error'=>string]
function mpFetchGovPage($apiKey, $state, $offset, $limit, $timeout = 30) {
    if (!function_exists('curl_init')) {
        return ['ok' => false, 'records' => [], 'total' => null, 'error' => 'curl_missing'];
    }
    $url = 'https://api.data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070?' . http_build_query([
        'api-key' => $apiKey,
        'format' => 'json',
        'offset' => (int)$offset,
        'limit' => (int)$limit,
        'filters[state]' => $state,
    ], '', '&', PHP_QUERY_RFC3986);

    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 8);
    curl_setopt($ch, CURLOPT_TIMEOUT, max(2, (int)$timeout));
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['Accept: application/json']);
    $response = curl_exec($ch);
    $errno = curl_errno($ch);
    $httpCode = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    // Never include the URL (it carries the key) in any error text.
    if ($response === false || $errno !== 0) {
        return ['ok' => false, 'records' => [], 'total' => null, 'error' => 'curl_error_' . $errno];
    }
    if ($httpCode !== 200) {
        return ['ok' => false, 'records' => [], 'total' => null, 'error' => 'http_' . $httpCode];
    }
    $data = json_decode($response, true);
    if (!is_array($data)) {
        return ['ok' => false, 'records' => [], 'total' => null, 'error' => 'invalid_json'];
    }
    if (!isset($data['records']) || !is_array($data['records'])) {
        return ['ok' => false, 'records' => [], 'total' => null, 'error' => 'bad_response_shape'];
    }
    $total = isset($data['total']) && is_numeric($data['total']) ? (int)$data['total'] : null;
    return ['ok' => true, 'records' => $data['records'], 'total' => $total, 'error' => ''];
}

// All pages (offset paging, up to 1000/page requested) for one exact upstream state name.
// Upstream may clamp the page size, so paging advances by the number of records actually received and stops only
// when a page is empty, the reported `total` has been reached, the page cap is hit (partial=true) or the optional
// $deadline (unix float) passes (partial=true).
// Returns ['success'=>true,'records'=>[normalised...],'partial'=>bool,'skipped'=>int]
// or ['success'=>false,'error'=>'missing_api_key'|'upstream_unavailable','detail'=>...]
function mpFetchGovRecords($state, $maxPages = 20, $deadline = null) {
    $state = trim((string)$state);
    if ($state === '') return ['success' => false, 'error' => 'state_required'];
    $apiKey = mpGetApiKey();
    if ($apiKey === '') return ['success' => false, 'error' => 'missing_api_key'];

    $limit = 1000;
    $all = [];
    $skipped = 0;
    $partial = false;
    $offset = 0;
    $received = 0;
    $total = null;
    for ($page = 0; $page < $maxPages; $page++) {
        $timeout = 30;
        if ($deadline !== null) {
            $remaining = $deadline - microtime(true);
            if ($page > 0 && $remaining <= 0) { $partial = true; break; }
            $timeout = (int)max(2, min(30, ceil($remaining)));
        }
        $res = mpFetchGovPage($apiKey, $state, $offset, $limit, $timeout);
        if (!$res['ok']) {
            if ($page === 0) {
                return ['success' => false, 'error' => 'upstream_unavailable', 'detail' => $res['error']];
            }
            $partial = true;
            break;
        }
        $n = count($res['records']);
        if ($n === 0) break;
        foreach ($res['records'] as $raw) {
            $norm = mpNormalizeGovRecord($raw);
            if ($norm === null) { $skipped++; continue; }
            $all[] = $norm;
        }
        $offset += $n;
        $received += $n;
        if ($res['total'] !== null) $total = $res['total'];
        if ($total !== null && $received >= $total) break;
        // Reaching here means more data may remain; if this was the last allowed page the result is partial.
        if ($page === $maxPages - 1) $partial = true;
    }
    return ['success' => true, 'records' => $all, 'partial' => $partial, 'skipped' => $skipped];
}

// One transaction for a set of rows. Throws on any failure (after the caller rolls back).
function mpStoreBatch($pdo, $stmt, $state, $rows) {
    $stored = 0;
    $pdo->beginTransaction();
    foreach ($rows as $r) {
        $ok = $stmt->execute([
            $state,
            $r['district'],
            $r['market'],
            $r['commodity'],
            $r['variety'],
            $r['grade'],
            $r['arrival_date'],
            $r['min_price'],
            $r['max_price'],
            $r['modal_price'],
        ]);
        if (!$ok) throw new RuntimeException('execute_failed');
        $stored++;
    }
    $pdo->commit();
    return $stored;
}

// Bulk upsert. $state is the CANONICAL state name (rows are always stored under it). ON DUPLICATE KEY UPDATE also
// flips any matching legacy row to source='gov'. One transaction for everything; if that fails, retry in chunks of
// 200 rows so a single bad chunk does not lose the whole state. Returns rows written, or -1 if nothing could be written.
function mpStoreRecords($pdo, $state, $rows) {
    if (empty($rows)) return 0;
    try {
        $stmt = $pdo->prepare("
            INSERT INTO market_prices_history
            (state, district, market, commodity, variety, grade, arrival_date, min_price, max_price, modal_price, source)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'gov')
            ON DUPLICATE KEY UPDATE
                grade = VALUES(grade),
                min_price = VALUES(min_price),
                max_price = VALUES(max_price),
                modal_price = VALUES(modal_price),
                source = 'gov'
        ");
    } catch (Throwable $e) {
        return -1;
    }

    try {
        return mpStoreBatch($pdo, $stmt, $state, $rows);
    } catch (Throwable $e) {
        try { if ($pdo->inTransaction()) $pdo->rollBack(); } catch (Throwable $e2) {}
    }

    $stored = 0;
    $okChunks = 0;
    foreach (array_chunk($rows, 200) as $chunk) {
        try {
            $stored += mpStoreBatch($pdo, $stmt, $state, $chunk);
            $okChunks++;
        } catch (Throwable $e) {
            try { if ($pdo->inTransaction()) $pdo->rollBack(); } catch (Throwable $e2) {}
        }
    }
    return $okChunks > 0 ? $stored : -1;
}

// Fetch the latest upstream data for one state and store it (real rows only).
// $userFacing = true (inside a user request): at most 3 pages and a ~10s overall deadline. The cron path keeps the full cap.
function fetchAndStoreMarketPrices($pdo, $state, $userFacing = false) {
    ensureMarketPricesTable($pdo);
    $canon = mpCanonicalState($state);
    if ($canon === '') return ['success' => false, 'error' => 'state_required', 'message' => 'State is required'];

    $maxPages = $userFacing ? 3 : 20;
    $deadline = $userFacing ? microtime(true) + 10 : null;

    $candidates = array_merge([$canon], mpStateUpstreamAlternates()[$canon] ?? []);
    $fetched = null;
    foreach ($candidates as $i => $cand) {
        if ($i > 0 && $deadline !== null && microtime(true) >= $deadline) break;
        $fetched = mpFetchGovRecords($cand, $maxPages, $deadline);
        if (($fetched['success'] ?? false) !== true) {
            $out = [
                'success' => false,
                'state' => $canon,
                'error' => $fetched['error'] ?? 'upstream_unavailable',
                'message' => 'Could not fetch market prices from upstream.',
            ];
            if (isset($fetched['detail'])) {
                // e.g. http_403 / curl_error_28 / invalid_json - never contains the URL or key.
                $out['detail'] = preg_replace('/[^A-Za-z0-9_.:-]/', '', (string)$fetched['detail']);
            }
            return $out;
        }
        if (!empty($fetched['records'])) break;
    }

    $records = $fetched['records'] ?? [];
    if (empty($records)) {
        return ['success' => true, 'state' => $canon, 'fetched' => 0, 'stored' => 0, 'message' => 'Synced 0 records (no upstream data).'];
    }
    $stored = mpStoreRecords($pdo, $canon, $records);
    if ($stored < 0) {
        return ['success' => false, 'state' => $canon, 'error' => 'db_error', 'message' => 'Failed to store records.'];
    }
    return [
        'success' => true,
        'state' => $canon,
        'fetched' => count($records),
        'stored' => $stored,
        'skipped' => (int)($fetched['skipped'] ?? 0),
        'partial' => !empty($fetched['partial']),
        'message' => "Synced $stored records.",
    ];
}

// At most one upstream attempt per key (state, or 'live:<state>') per 15 minutes. Atomic: an UPDATE that only
// matches an expired row, else INSERT IGNORE of a missing row; exactly one concurrent caller can win either step.
// Falls back to a temp-file lock if the table is unusable.
function mpSyncThrottleAllow($pdo, $key) {
    $key = mb_substr((string)$key, 0, 100, 'UTF-8');
    try {
        $up = $pdo->prepare("UPDATE market_sync_log SET last_attempt = NOW() WHERE state = ? AND last_attempt < NOW() - INTERVAL 15 MINUTE");
        $up->execute([$key]);
        if ($up->rowCount() > 0) return true;
        $ins = $pdo->prepare("INSERT IGNORE INTO market_sync_log (state, last_attempt) VALUES (?, NOW())");
        $ins->execute([$key]);
        return $ins->rowCount() > 0;
    } catch (Throwable $e) {
        $file = rtrim(sys_get_temp_dir(), '/\\') . '/mp_sync_' . md5($key) . '.lock';
        if (is_file($file) && (time() - (int)@filemtime($file)) < 900) return false;
        @touch($file);
        return true;
    }
}

// ---------------------------------------------------------------------------
// DB queries
// ---------------------------------------------------------------------------

function mpLatestDate($pdo, $variants) {
    list($where, $params) = mpStateWhere($variants);
    $stmt = $pdo->prepare("SELECT MAX(arrival_date) FROM market_prices_history WHERE $where");
    $stmt->execute($params);
    $v = $stmt->fetchColumn();
    return $v ? (string)$v : null;
}

// Exact (normalised) commodity match when it exists, else $fallback ('contains' | 'prefix').
// Returns [sqlFragment, params] to be AND-ed into a WHERE.
function mpCommodityClause($pdo, $baseWhere, $baseParams, $commodity, $fallback) {
    $c = mb_strtolower(trim($commodity), 'UTF-8');
    $exact = false;
    try {
        $stmt = $pdo->prepare("SELECT 1 FROM market_prices_history WHERE $baseWhere AND commodity = ? LIMIT 1");
        $stmt->execute(array_merge($baseParams, [$c]));
        $exact = (bool)$stmt->fetchColumn();
    } catch (Throwable $e) {}
    if ($exact) {
        return ['commodity = ?', [$c]];   // collation is case-insensitive; keeps idx_state_comm_date usable
    }
    $esc = mpLikeEscape($c);
    if ($fallback === 'prefix') {
        return ['(LOWER(commodity) LIKE ? OR LOWER(commodity) LIKE ? OR LOWER(commodity) LIKE ?)', [$esc . '(%', $esc . ' %', $esc . ',%']];
    }
    return ['LOWER(commodity) LIKE ?', ['%' . $esc . '%']];
}

function mpFormatRecord($row, $dateFormat = 'Y-m-d') {
    $date = (string)($row['arrival_date'] ?? '');
    if ($dateFormat !== 'Y-m-d' && $date !== '') {
        $ts = strtotime($date);
        if ($ts !== false) $date = date($dateFormat, $ts);
    }
    return [
        'commodity' => $row['commodity'] ?? '',
        'variety' => $row['variety'] ?? 'Other',
        'grade' => $row['grade'] ?? 'FAQ',
        'market' => $row['market'] ?? '',
        'district' => $row['district'] ?? '',
        'state' => $row['state'] ?? '',
        'min_price' => $row['min_price'] ?? '0',
        'max_price' => $row['max_price'] ?? '0',
        'modal_price' => $row['modal_price'] ?? '0',
        'arrival_date' => $date,
        'image_url' => resolveCommodityImageUrl($row['commodity'] ?? ''),
    ];
}

// Records for state/date window. $limit null = no paging (hard safety cap 20000).
// Returns ['records'=>[...], 'total'=>int]
function mpQueryRecords($pdo, $variants, $from, $to, $district, $commodity, $limit, $offset, $dateFormat = 'Y-m-d') {
    list($where, $params) = mpStateWhere($variants);
    $where .= " AND arrival_date BETWEEN ? AND ?";
    $params[] = $from;
    $params[] = $to;

    if ($commodity !== null && trim($commodity) !== '') {
        list($frag, $fragParams) = mpCommodityClause($pdo, $where, $params, $commodity, 'contains');
        $where .= " AND " . $frag;
        $params = array_merge($params, $fragParams);
    }

    $cnt = $pdo->prepare("SELECT COUNT(*) FROM market_prices_history WHERE $where");
    $cnt->execute($params);
    $total = (int)$cnt->fetchColumn();

    $orderParams = [];
    $order = '';
    if ($district !== null && $district !== '') {
        $order .= "(LOWER(TRIM(district)) = ?) DESC, ";
        $orderParams[] = mb_strtolower(trim($district), 'UTF-8');
    }
    $order .= "arrival_date DESC, commodity ASC, market ASC, id ASC";

    $sql = "SELECT * FROM market_prices_history WHERE $where ORDER BY $order";
    if ($limit === null) {
        $sql .= " LIMIT 20000";
    } else {
        $sql .= " LIMIT " . (int)$limit . " OFFSET " . (int)$offset;
    }
    $stmt = $pdo->prepare($sql);
    $stmt->execute(array_merge($params, $orderParams));
    $records = [];
    foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $row) {
        $records[] = mpFormatRecord($row, $dateFormat);
    }
    return ['records' => $records, 'total' => $total];
}

// True when the latest date has < 60% of the distinct commodities seen in the 3 days before it (a thin, partial day).
function mpLatestIsSparse($pdo, $variants, $latest) {
    try {
        list($where, $params) = mpStateWhere($variants);
        $stmt = $pdo->prepare("SELECT COUNT(DISTINCT commodity) FROM market_prices_history WHERE $where AND arrival_date = ?");
        $stmt->execute(array_merge($params, [$latest]));
        $cur = (int)$stmt->fetchColumn();
        $stmt = $pdo->prepare("SELECT COUNT(DISTINCT commodity) FROM market_prices_history WHERE $where AND arrival_date BETWEEN ? AND ?");
        $stmt->execute(array_merge($params, [
            date('Y-m-d', strtotime($latest . ' -3 days')),
            date('Y-m-d', strtotime($latest . ' -1 days')),
        ]));
        $prev = (int)$stmt->fetchColumn();
        return $prev > 0 && $cur < 0.6 * $prev;
    } catch (Throwable $e) {
        return false;
    }
}

function mpStateEmptySyncAttempt($pdo, $state) {
    // Only for recognised states, throttled to one upstream attempt / 15 min / state.
    if (!in_array($state, mpAllStates(), true)) return;
    if (!mpSyncThrottleAllow($pdo, $state)) return;
    try {
        fetchAndStoreMarketPrices($pdo, $state, true);   // user-facing: <= 3 pages, ~10s deadline
    } catch (Throwable $e) {}
}

// ---------------------------------------------------------------------------
// Endpoints
// ---------------------------------------------------------------------------

function mpSendCache($seconds = 300) {
    if (!headers_sent()) header('Cache-Control: public, max-age=' . (int)$seconds);
}

// GET get_market_prices
function getMarketPrices($pdo) {
    ensureMarketPricesTable($pdo);
    $requested = trim((string)($_GET['state'] ?? ''));
    if ($requested === '') {
        mpJsonOut(['success' => false, 'error' => 'state_required', 'message' => 'state is required']);
        return;
    }
    $districtIn = trim((string)($_GET['district'] ?? ''));
    $commodityIn = trim((string)($_GET['commodity'] ?? ''));
    $lang = strtolower(trim((string)($_GET['lang'] ?? 'en')));
    if (!in_array($lang, ['en', 'hi', 'te'], true)) $lang = 'en';
    $limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 500;
    if ($limit < 1) $limit = 500;
    if ($limit > 1000) $limit = 1000;
    $offset = isset($_GET['offset']) ? max(0, (int)$_GET['offset']) : 0;
    $days = isset($_GET['days']) ? (int)$_GET['days'] : 3;
    if ($days < 1) $days = 1;
    if ($days > 7) $days = 7;
    $dateParam = trim((string)($_GET['date'] ?? 'latest'));
    if ($dateParam === '') $dateParam = 'latest';
    if ($dateParam !== 'latest' && !mpValidYmd($dateParam)) {
        mpJsonOut(['success' => false, 'error' => 'invalid_date', 'message' => "date must be 'latest' or Y-m-d"]);
        return;
    }

    $state = mpResolveState($pdo, $requested);
    $variants = mpStateVariants($state);

    $latest = mpLatestDate($pdo, $variants);
    if ($latest === null) {
        mpStateEmptySyncAttempt($pdo, $state);
        $latest = mpLatestDate($pdo, $variants);
    }

    if ($latest === null) {
        // Empty state: not cached (a sync may fill it any moment).
        mpJsonOut([
            'success' => true,
            'requested_state' => $requested,
            'state' => $state,
            'as_of' => null,
            'matched_level' => 'none',
            'error_hint' => 'no_data_for_state',
            'resolved' => ['state' => $state, 'district' => null],
            'total' => 0,
            'count' => 0,
            'limit' => $limit,
            'offset' => $offset,
            'records' => [],
            'commodities' => [],
            'districts' => [],
        ]);
        return;
    }

    mpSendCache(300);   // only non-error, non-empty responses are cacheable

    $asOf = $dateParam === 'latest' ? $latest : $dateParam;
    $windowExtended = false;
    if ($dateParam === 'latest' && $days < 3 && mpLatestIsSparse($pdo, $variants, $latest)) {
        $days = 3;
        $windowExtended = true;
    }
    $from = date('Y-m-d', strtotime($asOf . ' -' . ($days - 1) . ' days'));

    $resolvedDistrict = null;
    if ($districtIn !== '') {
        $resolvedDistrict = mpResolveDistrict($pdo, $variants, $districtIn);
    }

    $q = mpQueryRecords($pdo, $variants, $from, $asOf, $resolvedDistrict, $commodityIn, $limit, $offset);

    $resp = [
        'success' => true,
        'requested_state' => $requested,
        'state' => $state,
        'as_of' => $asOf,
        'matched_level' => $resolvedDistrict !== null ? 'district' : 'state',
        'resolved' => ['state' => $state, 'district' => $resolvedDistrict],
        'lang' => $lang,
        'days' => $days,
        'total' => $q['total'],
        'count' => count($q['records']),
        'limit' => $limit,
        'offset' => $offset,
        'records' => $q['records'],
    ];
    if ($windowExtended) $resp['window_extended'] = true;
    if ($dateParam === 'latest' && $latest < date('Y-m-d', strtotime('-3 days'))) {
        $resp['stale'] = true;
    }

    if ($offset === 0) {
        list($where, $params) = mpStateWhere($variants);
        $where .= " AND arrival_date BETWEEN ? AND ?";
        $params[] = $from;
        $params[] = $asOf;

        $commodities = [];
        $stmt = $pdo->prepare("SELECT commodity, COUNT(*) AS c, MIN(modal_price) AS lo, MAX(modal_price) AS hi FROM market_prices_history WHERE $where GROUP BY commodity ORDER BY c DESC, commodity ASC");
        $stmt->execute($params);
        foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $r) {
            $commodities[] = [
                'commodity' => $r['commodity'],
                'count' => (int)$r['c'],
                'min_modal' => (float)$r['lo'],
                'max_modal' => (float)$r['hi'],
            ];
        }
        $districts = [];
        $stmt = $pdo->prepare("SELECT district, COUNT(*) AS c FROM market_prices_history WHERE $where AND district <> '' GROUP BY district ORDER BY c DESC, district ASC");
        $stmt->execute($params);
        foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $r) {
            $districts[] = ['district' => $r['district'], 'count' => (int)$r['c']];
        }
        $resp['commodities'] = $commodities;
        $resp['districts'] = $districts;
    }

    mpJsonOut($resp);
}

// GET get_market_locations
function getMarketLocations($pdo) {
    ensureMarketPricesTable($pdo);
    mpSendCache(300);

    $states = [];
    $stmt = $pdo->query("SELECT state, MAX(arrival_date) AS latest, COUNT(DISTINCT commodity) AS cc FROM market_prices_history WHERE state <> ''" . mpSourceClause() . " GROUP BY state");
    foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $r) {
        $canon = mpCanonicalState($r['state']);
        if (!isset($states[$canon])) {
            $states[$canon] = ['state' => $canon, 'districts' => [], 'latest_date' => null, 'commodity_count' => 0];
        }
        if ($r['latest'] !== null && ($states[$canon]['latest_date'] === null || $r['latest'] > $states[$canon]['latest_date'])) {
            $states[$canon]['latest_date'] = $r['latest'];
        }
        $states[$canon]['commodity_count'] = max($states[$canon]['commodity_count'], (int)$r['cc']);
    }

    $stmt = $pdo->query("SELECT DISTINCT state, district FROM market_prices_history WHERE state <> '' AND district <> ''" . mpSourceClause());
    foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $r) {
        $canon = mpCanonicalState($r['state']);
        if (!isset($states[$canon])) continue;
        $states[$canon]['districts'][$r['district']] = true;
    }

    $out = [];
    foreach ($states as $s) {
        $d = array_keys($s['districts']);
        sort($d, SORT_NATURAL | SORT_FLAG_CASE);
        $s['districts'] = array_values(array_map('strval', $d));
        $out[] = $s;
    }
    usort($out, function ($a, $b) { return strcasecmp($a['state'], $b['state']); });

    mpJsonOut(['success' => true, 'states' => $out]);
}

// Daily points for a trends WHERE. The daily value is the MEDIAN modal price across the rows reported that day
// (computed in PHP; MySQL has no median), which is far less jumpy than an average when the set of reporting
// markets changes day to day. Keys: date, min_price, max_price, modal_price.
function mpTrendPoints($pdo, $where, $params, $days) {
    $stmt = $pdo->prepare("SELECT MAX(arrival_date) FROM market_prices_history WHERE $where");
    $stmt->execute($params);
    $maxDate = $stmt->fetchColumn();
    if (!$maxDate) return [];
    $from = date('Y-m-d', strtotime($maxDate . ' -' . ($days - 1) . ' days'));
    $stmt = $pdo->prepare("
        SELECT arrival_date, min_price, max_price, modal_price
        FROM market_prices_history
        WHERE $where AND arrival_date BETWEEN ? AND ?
        ORDER BY arrival_date ASC
        LIMIT 50000
    ");
    $stmt->execute(array_merge($params, [$from, $maxDate]));
    $byDay = [];
    foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $r) {
        $d = (string)$r['arrival_date'];
        if (!isset($byDay[$d])) $byDay[$d] = ['lo' => null, 'hi' => null, 'modals' => []];
        $lo = (float)$r['min_price'];
        $hi = (float)$r['max_price'];
        if ($byDay[$d]['lo'] === null || $lo < $byDay[$d]['lo']) $byDay[$d]['lo'] = $lo;
        if ($byDay[$d]['hi'] === null || $hi > $byDay[$d]['hi']) $byDay[$d]['hi'] = $hi;
        $byDay[$d]['modals'][] = (float)$r['modal_price'];
    }
    ksort($byDay);
    $points = [];
    foreach ($byDay as $d => $v) {
        $m = $v['modals'];
        sort($m, SORT_NUMERIC);
        $c = count($m);
        $mid = intdiv($c, 2);
        $median = ($c % 2 === 1) ? $m[$mid] : ($m[$mid - 1] + $m[$mid]) / 2;
        $points[] = [
            'date' => (string)$d,
            'min_price' => round((float)$v['lo'], 2),
            'max_price' => round((float)$v['hi'], 2),
            'modal_price' => round((float)$median, 2),
        ];
    }
    return $points;
}

// get_commodity_trends (legacy keys kept: success, trends[{arrival_date, avg_price}])
function getCommodityTrends($pdo) {
    ensureMarketPricesTable($pdo);
    $stateIn = trim((string)($_GET['state'] ?? ''));
    $districtIn = trim((string)($_GET['district'] ?? ''));
    $commodity = trim((string)($_GET['commodity'] ?? ''));
    $days = isset($_GET['days']) ? (int)$_GET['days'] : 30;
    if ($days < 1) $days = 30;
    if ($days > 90) $days = 90;

    if ($commodity === '') {
        mpJsonOut(['success' => false, 'error' => 'commodity_required', 'message' => 'commodity is required']);
        return;
    }

    $state = '';
    $baseWhere = '1=1' . mpSourceClause();
    $baseParams = [];
    $resolvedDistrict = null;
    if ($stateIn !== '') {
        $state = mpResolveState($pdo, $stateIn);
        $variants = mpStateVariants($state);
        list($baseWhere, $baseParams) = mpStateWhere($variants);
        if ($districtIn !== '') {
            $resolvedDistrict = mpResolveDistrict($pdo, $variants, $districtIn);
        }
    }
    $baseWhere .= " AND modal_price > 0";

    // Attempt order: district (when resolved), then state-wide. A district with < 2 points falls back to state level.
    $attempts = [];
    if ($resolvedDistrict !== null) {
        $attempts[] = [$baseWhere . " AND district = ?", array_merge($baseParams, [$resolvedDistrict]), 'district'];
    }
    $attempts[] = [$baseWhere, $baseParams, 'state'];

    $points = [];
    $matchedLevel = 'state';
    foreach ($attempts as $att) {
        list($where, $params, $level) = $att;
        list($frag, $fragParams) = mpCommodityClause($pdo, $where, $params, $commodity, 'prefix');
        $where .= " AND " . $frag;
        $params = array_merge($params, $fragParams);
        $points = mpTrendPoints($pdo, $where, $params, $days);
        $matchedLevel = $level;
        if (count($points) >= 2) break;
    }
    if ($matchedLevel !== 'district') $resolvedDistrict = null;

    $insufficient = count($points) < 2;
    $trends = [];
    if ($insufficient) {
        $points = [];
    } else {
        foreach ($points as $p) {
            $trends[] = ['arrival_date' => $p['date'], 'avg_price' => $p['modal_price']];
        }
    }

    mpSendCache(300);
    $resp = [
        'success' => true,
        'state' => $state,
        'commodity' => $commodity,
        'days' => $days,
        'matched_level' => $matchedLevel,
        'resolved' => ['state' => $state, 'district' => $resolvedDistrict],
        'points' => $points,
        'trends' => $trends,
    ];
    if ($insufficient) $resp['insufficient_data'] = true;
    mpJsonOut($resp);
}

// Protected: CLI, or the X-Sync-Token HEADER equal to MARKET_SYNC_TOKEN (web disabled if unset). Never accepted via ?token=
// (query strings end up in access logs).
function syncMarketPrices($pdo) {
    ensureMarketPricesTable($pdo);
    if (php_sapi_name() !== 'cli') {
        $expected = mpConfigValue('MARKET_SYNC_TOKEN');
        if ($expected === '') {
            http_response_code(403);
            mpJsonOut(['success' => false, 'error' => 'sync_disabled']);
            return;
        }
        $provided = $_SERVER['HTTP_X_SYNC_TOKEN'] ?? '';
        if (!is_string($provided) || $provided === '' || !hash_equals($expected, $provided)) {
            http_response_code(403);
            mpJsonOut(['success' => false, 'error' => 'unauthorized']);
            return;
        }
    }
    @set_time_limit(180);

    $statesParam = trim((string)($_GET['states'] ?? ($_GET['state'] ?? 'Telangana')));
    $states = array_values(array_filter(array_map('trim', explode(',', $statesParam))));
    $states = array_slice($states, 0, 5);

    $results = [];
    foreach ($states as $s) {
        $r = fetchAndStoreMarketPrices($pdo, $s);
        $results[] = [
            'state' => $r['state'] ?? $s,
            'success' => (bool)($r['success'] ?? false),
            'stored' => (int)($r['stored'] ?? 0),
            'error' => $r['error'] ?? null,
            'detail' => $r['detail'] ?? null,
        ];
    }
    mpJsonOut(['success' => true, 'results' => $results]);
}

// Legacy: get_live_state_market_prices. Live upstream data (latest date only); on failure DB rows as stale; else error.
function getLiveStateMarketPrices($pdo) {
    ensureMarketPricesTable($pdo);
    $requested = trim((string)($_GET['state'] ?? 'Telangana'));
    if ($requested === '') $requested = 'Telangana';
    $state = mpResolveState($pdo, $requested);

    // Upstream is hit at most once per state per 15 minutes (atomic throttle); otherwise serve stored rows below.
    $fetched = null;
    $throttled = !mpSyncThrottleAllow($pdo, 'live:' . $state);
    if (!$throttled) {
        $deadline = microtime(true) + 10;
        foreach (array_merge([$state], mpStateUpstreamAlternates()[$state] ?? []) as $i => $cand) {
            if ($i > 0 && microtime(true) >= $deadline) break;
            $fetched = mpFetchGovRecords($cand, 3, $deadline);
            if (($fetched['success'] ?? false) !== true) break;
            if (!empty($fetched['records'])) break;
        }
    }

    if (($fetched['success'] ?? false) === true && !empty($fetched['records'])) {
        $latest = '';
        foreach ($fetched['records'] as $r) {
            if ($r['arrival_date'] > $latest) $latest = $r['arrival_date'];
        }
        $records = [];
        foreach ($fetched['records'] as $r) {
            if ($r['arrival_date'] !== $latest) continue;
            $records[] = [
                'commodity' => $r['commodity'],
                'variety' => $r['variety'],
                'grade' => $r['grade'],
                'market' => $r['market'],
                'district' => $r['district'],
                'state' => $state,
                'min_price' => (string)$r['min_price'],
                'max_price' => (string)$r['max_price'],
                'modal_price' => (string)$r['modal_price'],
                'arrival_date' => date('d/m/Y', strtotime($latest)),
                'image_url' => resolveCommodityImageUrl($r['commodity']),
            ];
        }
        mpJsonOut([
            'success' => true,
            'state' => $state,
            'date' => date('d/m/Y', strtotime($latest)),
            'records' => $records,
            'source' => 'live_api',
        ]);
        return;
    }

    // Upstream failed, empty or throttled: serve real stored rows if any (flagged stale), else report the failure.
    $variants = mpStateVariants($state);
    $latestDb = mpLatestDate($pdo, $variants);
    if ($latestDb !== null) {
        $q = mpQueryRecords($pdo, $variants, $latestDb, $latestDb, null, null, null, 0, 'd/m/Y');
        mpJsonOut([
            'success' => true,
            'state' => $state,
            'date' => date('d/m/Y', strtotime($latestDb)),
            'as_of' => $latestDb,
            'stale' => true,
            'records' => $q['records'],
            'source' => 'db',
        ]);
        return;
    }

    $err = $fetched['error'] ?? 'upstream_unavailable';   // throttled with no stored rows => upstream_unavailable
    if ($err === 'missing_api_key') {
        mpJsonOut(['success' => false, 'error' => 'missing_api_key', 'message' => 'Market price source is not configured.']);
        return;
    }
    mpJsonOut(['success' => false, 'error' => 'upstream_unavailable', 'message' => 'Live market prices are temporarily unavailable.']);
}

// Legacy: get_state_market_prices. Latest date, all rows (no 200 cap), real data only.
function getStateMarketPrices($pdo) {
    ensureMarketPricesTable($pdo);
    $requested = trim((string)($_GET['state'] ?? 'Telangana'));
    if ($requested === '') $requested = 'Telangana';
    $state = mpResolveState($pdo, $requested);
    $variants = mpStateVariants($state);

    $latest = mpLatestDate($pdo, $variants);
    if ($latest === null) {
        mpStateEmptySyncAttempt($pdo, $state);
        $latest = mpLatestDate($pdo, $variants);
    }

    if ($latest === null) {
        mpJsonOut([
            'success' => true,
            'date' => date('d/m/Y'),
            'state' => $state,
            'records' => [],
            'error_hint' => 'no_data_for_state',
        ]);
        return;
    }

    $q = mpQueryRecords($pdo, $variants, $latest, $latest, null, null, null, 0, 'Y-m-d');
    $resp = [
        'success' => true,
        'date' => date('d/m/Y', strtotime($latest)),
        'state' => $state,
        'records' => $q['records'],
    ];
    if ($latest < date('Y-m-d', strtotime('-3 days'))) {
        $resp['stale'] = true;
        $resp['as_of'] = $latest;
    }
    mpJsonOut($resp);
}
?>
