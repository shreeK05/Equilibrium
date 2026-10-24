-- AlterTable
ALTER TABLE "Task" ADD COLUMN "actualMinutes" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "Task" ADD COLUMN "remainingMinutes" INTEGER;
