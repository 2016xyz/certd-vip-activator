CREATE TABLE "pi_template"
(
  "id"          integer PRIMARY KEY AUTOINCREMENT NOT NULL,
  "user_id"     integer,
  "pipeline_id" integer,
  "title"       varchar(1024),
  "content"     text,
  "order"       integer,
  "desc"        varchar(1024),
  "disabled"    boolean  NOT NULL DEFAULT (false),
  "create_time" datetime NOT NULL DEFAULT (CURRENT_TIMESTAMP),
  "update_time" datetime NOT NULL DEFAULT (CURRENT_TIMESTAMP)
);

CREATE INDEX "index_template_user_id" ON "pi_template" ("user_id");
CREATE INDEX "index_template_pipeline_id" ON "pi_template" ("pipeline_id");

ALTER TABLE pi_pipeline ADD COLUMN "template_id" integer DEFAULT (0);
ALTER TABLE pi_pipeline ADD COLUMN "is_template" boolean DEFAULT (0);
CREATE INDEX "index_pipeline_template_id" ON "pi_pipeline" ("template_id");
