ALTER TABLE cd_site_info ADD COLUMN "remark" varchar(512);

CREATE TABLE "cd_group"
(
  "id"          integer PRIMARY KEY AUTOINCREMENT NOT NULL,
  "user_id"     integer      NOT NULL,
  "name"        varchar(100) NOT NULL,
  "icon"        varchar(100),
  "favorite"    boolean      NOT NULL DEFAULT (false),
  "type"        varchar(512),
  "create_time" datetime     NOT NULL DEFAULT (CURRENT_TIMESTAMP),
  "update_time" datetime     NOT NULL DEFAULT (CURRENT_TIMESTAMP)
);

ALTER TABLE cd_site_info ADD COLUMN "group_id" integer;

ALTER TABLE pi_pipeline ADD COLUMN "valid_time" integer;
