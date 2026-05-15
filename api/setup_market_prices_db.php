<?php
require_once '../config.php';

try {
    $sql = "
    CREATE TABLE IF NOT EXISTS market_prices_history (
        id INT AUTO_INCREMENT PRIMARY KEY,
        state VARCHAR(100) NOT NULL,
        district VARCHAR(100) NOT NULL,
        market VARCHAR(100) NOT NULL,
        commodity VARCHAR(100) NOT NULL,
        variety VARCHAR(100),
        grade VARCHAR(50),
        arrival_date DATE NOT NULL,
        min_price DECIMAL(10,2),
        max_price DECIMAL(10,2),
        modal_price DECIMAL(10,2),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY unique_daily_record (state, district, market, commodity, variety, arrival_date)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ";

    $pdo->exec($sql);
    echo "Table market_prices_history created successfully.\n";

    // Add index for faster querying
    $pdo->exec("CREATE INDEX IF NOT EXISTS idx_state_district ON market_prices_history(state, district)");
    $pdo->exec("CREATE INDEX IF NOT EXISTS idx_commodity ON market_prices_history(commodity, arrival_date)");

    echo "Indexes created successfully.\n";
} catch (PDOException $e) {
    echo "Error creating table: " . $e->getMessage() . "\n";
}
?>
