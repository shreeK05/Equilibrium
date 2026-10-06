-- Sleep Shield timezone repair.
-- No client ever sent a timezone at registration, so every app-registered user silently
-- inherited the "UTC" default and had their sleep window evaluated 5h30m off (a 23:00 IST
-- bedtime was treated as 04:30 IST). No UI exists that lets a user choose "UTC", so any
-- stored "UTC" is the unintended default, not a user choice.
ALTER TABLE "User" ALTER COLUMN "timezone" SET DEFAULT 'Asia/Kolkata';
UPDATE "User" SET "timezone" = 'Asia/Kolkata' WHERE "timezone" = 'UTC';
