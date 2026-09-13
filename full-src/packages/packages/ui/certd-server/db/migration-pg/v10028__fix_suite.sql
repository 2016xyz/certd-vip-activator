update cd_user_suite set is_empty = false where is_empty is null;
ALTER TABLE "cd_user_suite" ALTER COLUMN "is_empty" SET DEFAULT false;
