ALTER TABLE pi_plugin ADD COLUMN `pluginType` varchar(100);
ALTER TABLE pi_plugin ADD COLUMN `metadata` longtext;
ALTER TABLE pi_plugin ADD COLUMN `author` varchar(100);
ALTER TABLE pi_plugin ADD COLUMN `extra` longtext;



CREATE TABLE `pi_sub_domain`
(
  `id`          bigint PRIMARY KEY AUTO_INCREMENT NOT NULL,
  `user_id`     bigint,
  `domain`  varchar(100),
  `disabled`    boolean  NOT NULL DEFAULT false,
  `create_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `update_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);


CREATE INDEX `index_sub_domain_user_id` ON `pi_sub_domain` (`user_id`);
CREATE INDEX `index_sub_domain_domain` ON `pi_sub_domain` (`domain`);
