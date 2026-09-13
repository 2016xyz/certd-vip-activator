
CREATE TABLE "cd_oauth_bound"
(
  "id"          integer PRIMARY KEY AUTOINCREMENT NOT NULL,
  "user_id"     integer      NOT NULL,
  "type"        varchar(512) NOT NULL,
  "open_id"     varchar(512) NOT NULL,
  "create_time" datetime     NOT NULL DEFAULT (CURRENT_TIMESTAMP),
  "update_time" datetime     NOT NULL DEFAULT (CURRENT_TIMESTAMP)
);


CREATE INDEX "index_oauth_bound_user_id" ON "cd_oauth_bound" ("user_id");
CREATE INDEX "index_oauth_bound_open_id" ON "cd_oauth_bound" ("open_id");
