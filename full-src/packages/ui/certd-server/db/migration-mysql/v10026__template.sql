CREATE TABLE `pi_template`
(
  `id`          bigint PRIMARY KEY AUTO_INCREMENT NOT NULL,
  `user_id`     bigint,
  `pipeline_id` bigint,
  `title`       varchar(1024),
  `content`     longtext,
  `order`       bigint,
  `desc`        varchar(1024),
  `disabled`    boolean  NOT NULL DEFAULT false,
  `create_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `update_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX `index_template_user_id` ON `pi_template` (`user_id`);
CREATE INDEX `index_template_pipeline_id` ON `pi_template` (`pipeline_id`);

ALTER TABLE pi_pipeline ADD COLUMN `template_id` bigint DEFAULT 0;
ALTER TABLE pi_pipeline ADD COLUMN `is_template` boolean DEFAULT 0;
CREATE INDEX `index_pipeline_template_id` ON `pi_pipeline` (`template_id`);
