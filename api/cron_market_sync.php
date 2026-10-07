<?php
/**
 * cron_market_sync.php - sync latest data.gov.in mandi prices for every Indian state.
 *
 * CLI ONLY. Real upstream data only; nothing is fabricated.
 *
 * Environment (set in the cron environment / hosting panel, never in code):
 *   DATA_GOV_IN_API_KEY   data.gov.in API key (required; or define a constant of the same name in config.php)
 *   MARKET_SYNC_TOKEN     only needed for the optional web trigger of sync_market_prices (X-Sync-Token header only)
 *   MARKET_SHOW_LEGACY    leave unset; =1 would make the API serve unverified pre-fix rows
 * (Values are read from getenv(), $_SERVER, $_ENV or a constant of the same name.)
 *
 * Crontab (daily 07:00 and 15:00 IST; adjust if the server clock is not IST):
 *   0 7,15 * * * DATA_GOV_IN_API_KEY=your_key_here /usr/bin/php /path/to/api/cron_market_sync.php >> /path/to/market_sync.log 2>&1
 * Optional: sync only some states
 *   php cron_market_sync.php "Telangana,Andhra Pradesh"
 *
 * Exit codes: 0 ok, 1 missing API key / no DB connection, 2 every state failed.
 */

if (php_sapi_name() !== 'cli') {
    http_response_code(403);
    echo "This script can only be run from the command line.\n";
    exit(1);
}

if (file_exists(__DIR__ . '/config.php')) {
    require_once __DIR__ . '/config.php';
} elseif (file_exists(__DIR__ . '/../config.php')) {
    require_once __DIR__ . '/../config.php';
}
require_once __DIR__ . '/market_prices_api.php';

if (mpGetApiKey() === '') {
    fwrite(STDERR, "missing_api_key: set DATA_GOV_IN_API_KEY\n");
    exit(1);
}
if (!isset($pdo) || !($pdo instanceof PDO)) {
    fwrite(STDERR, "no_database_connection\n");
    exit(1);
}

@set_time_limit(0);
ensureMarketPricesTable($pdo);

$states = mpAllStates();
if (!empty($argv[1])) {
    $states = array_values(array_filter(array_map('trim', explode(',', $argv[1]))));
}

$ok = 0;
$failed = 0;
$totalStored = 0;
foreach ($states as $state) {
    $r = fetchAndStoreMarketPrices($pdo, $state);
    $name = $r['state'] ?? $state;
    if (($r['success'] ?? false) === true) {
        $ok++;
        $totalStored += (int)($r['stored'] ?? 0);
        echo date('c') . " $name: fetched=" . (int)($r['fetched'] ?? 0) . " stored=" . (int)($r['stored'] ?? 0)
            . " skipped=" . (int)($r['skipped'] ?? 0) . (!empty($r['partial']) ? ' partial=1' : '') . "\n";
    } else {
        $failed++;
        $detail = isset($r['detail']) && $r['detail'] !== '' ? ' detail=' . $r['detail'] : '';
        echo date('c') . " $name: error=" . ($r['error'] ?? 'unknown') . $detail . "\n";
        if (($r['error'] ?? '') === 'missing_api_key') {
            exit(1);
        }
    }
    sleep(1);
}

echo date('c') . " done: states_ok=$ok states_failed=$failed rows_stored=$totalStored\n";
exit($ok === 0 ? 2 : 0);
