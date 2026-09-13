update cd_user_suite set is_empty = false where is_empty is null;

ALTER TABLE cd_user_suite MODIFY COLUMN `is_empty` boolean default false ;
