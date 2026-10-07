<?php
// Copy this file to market_secrets.php (git-ignored) and fill in the real values.
// market_prices_api.php loads market_secrets.php automatically if it exists.
// Alternatively set the same names as server environment variables.

if (!defined('DATA_GOV_IN_API_KEY')) {
    define('DATA_GOV_IN_API_KEY', 'PASTE-YOUR-data.gov.in-API-KEY-HERE');
}

// Optional: enables the web `sync_market_prices` action (X-Sync-Token header).
// if (!defined('MARKET_SYNC_TOKEN')) { define('MARKET_SYNC_TOKEN', 'a-long-random-string'); }
