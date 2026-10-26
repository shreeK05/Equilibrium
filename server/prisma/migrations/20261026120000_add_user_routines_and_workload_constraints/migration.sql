-- AlterTable
ALTER TABLE "UserConstraint" ADD COLUMN "routinesJson" TEXT;
ALTER TABLE "UserConstraint" ADD COLUMN "maxDailyStudyMinutes" INTEGER DEFAULT 480;
ALTER TABLE "UserConstraint" ADD COLUMN "maxFocusSessionMinutes" INTEGER DEFAULT 120;
ALTER TABLE "UserConstraint" ADD COLUMN "preferredStudyHoursJson" TEXT;
