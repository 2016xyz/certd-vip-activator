
ALTER TABLE cd_site_info ADD COLUMN "ip_check" boolean;
ALTER TABLE cd_site_info ADD COLUMN "ip_count" integer;
ALTER TABLE cd_site_info ADD COLUMN "ip_error_count" integer;


CREATE TABLE "cd_site_ip"
(
  "id"                integer PRIMARY KEY AUTOINCREMENT NOT NULL,
  "user_id"           integer,
  "site_id"           integer,
  "ip_address"        varchar(100),
  "cert_domains"      varchar(10240),
  "cert_provider"     varchar(100),
  "cert_status"       varchar(100),
  "cert_expires_time" integer,
  "last_check_time"   integer,
  "check_status"      varchar(100),
  "error"             varchar(4096),
  "remark"            varchar(4096),
  "from"              varchar(100),
  "disabled"          boolean  NOT NULL DEFAULT (false),
  "create_time"       datetime NOT NULL DEFAULT (CURRENT_TIMESTAMP),
  "update_time"       datetime NOT NULL DEFAULT (CURRENT_TIMESTAMP)
);

CREATE INDEX "index_site_ip_user_id" ON "cd_site_ip" ("user_id");
CREATE INDEX "index_site_ip_site_id" ON "cd_site_ip" ("site_id");
