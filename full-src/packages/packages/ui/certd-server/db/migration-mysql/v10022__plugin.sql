ALTER TABLE pi_plugin
  MODIFY COLUMN `setting` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL AFTER `author`,
  MODIFY COLUMN `sys_setting` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL AFTER `setting`,
  MODIFY COLUMN `metadata` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL AFTER `sys_setting`,
  MODIFY COLUMN `content` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL AFTER `metadata`;
