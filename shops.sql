CREATE TABLE IF NOT EXISTS `aprts_shops` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `shop_id` varchar(50) NOT NULL,
  `label` varchar(255) DEFAULT 'Obchod',
  `owner` varchar(60) DEFAULT NULL,
  `coords` text NOT NULL,
  `products` longtext DEFAULT '[]', -- JSON s cenami a kategoriemi
  `money` int(11) DEFAULT 0,
  `expires_at` bigint(20) DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `shop_id` (`shop_id`)
);