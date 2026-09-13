
CREATE TABLE "cd_addon" (
  "id" integer PRIMARY KEY AUTOINCREMENT NOT NULL,
  "user_id" integer NOT NULL,
  "name" varchar(100) NOT NULL,
  "type" varchar(100) NOT NULL,
  "addon_type" varchar(100) NOT NULL,
  "is_default" boolean NOT NULL DEFAULT (false),
  "is_system" boolean NOT NULL DEFAULT (false),
  "setting" text,
  "create_time" datetime NOT NULL DEFAULT (CURRENT_TIMESTAMP),
  "update_time" datetime NOT NULL DEFAULT (CURRENT_TIMESTAMP)
);
