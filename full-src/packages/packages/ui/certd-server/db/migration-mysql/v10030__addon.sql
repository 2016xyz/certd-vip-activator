
CREATE TABLE `cd_addon` (
  `id` bigint PRIMARY KEY AUTO_INCREMENT NOT NULL,
  `user_id` bigint NOT NULL,
  `name` varchar(100) NOT NULL,
  `type` varchar(100) NOT NULL,
  `addon_type` varchar(100) NOT NULL,
  `is_default` boolean NOT NULL DEFAULT false,
  `is_system` boolean NOT NULL DEFAULT false,
  `setting` longtext,
  `create_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `update_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);
