CREATE TABLE IF NOT EXISTS shop_banners (
  id INT AUTO_INCREMENT PRIMARY KEY,
  tag_en VARCHAR(40), tag_hi VARCHAR(40), tag_te VARCHAR(40),
  title_en VARCHAR(120) NOT NULL, title_hi VARCHAR(120), title_te VARCHAR(120),
  subtitle_en VARCHAR(200), subtitle_hi VARCHAR(200), subtitle_te VARCHAR(200),
  cta_text_en VARCHAR(40), cta_text_hi VARCHAR(40), cta_text_te VARCHAR(40),
  badge_en VARCHAR(30), badge_hi VARCHAR(30), badge_te VARCHAR(30),
  target_type ENUM('none','product','category','url') NOT NULL DEFAULT 'none',
  target_value VARCHAR(500) NULL,
  bg_color_1 CHAR(7) DEFAULT '#064E3B', bg_color_2 CHAR(7) DEFAULT '#047857',
  icon_key VARCHAR(40) NULL,
  image_url VARCHAR(500) NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  sort_order INT NOT NULL DEFAULT 0,
  start_at DATETIME NULL, end_at DATETIME NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_active_sort (is_active, sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
