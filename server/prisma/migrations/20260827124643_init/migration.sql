-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "timezone" TEXT NOT NULL DEFAULT 'UTC',
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL
);

-- CreateTable
CREATE TABLE "UserConstraint" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "userId" TEXT NOT NULL,
    "minSleepHours" REAL NOT NULL,
    "sleepStart" TEXT NOT NULL,
    "sleepEnd" TEXT NOT NULL,
    "bufferMinutes" INTEGER NOT NULL DEFAULT 30,
    "peakEnergyWindowsJson" TEXT NOT NULL,
    CONSTRAINT "UserConstraint_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "Task" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "userId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "estimateMinutes" INTEGER NOT NULL,
    "completedMinutes" INTEGER NOT NULL DEFAULT 0,
    "deadline" DATETIME NOT NULL,
    "academicWeight" REAL NOT NULL DEFAULT 0.5,
    "teamImpactWeight" REAL NOT NULL DEFAULT 0.0,
    "cognitiveLoad" TEXT NOT NULL DEFAULT 'MEDIUM',
    "deferralCount" INTEGER NOT NULL DEFAULT 0,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL,
    CONSTRAINT "Task_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "ScheduleVersion" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "userId" TEXT NOT NULL,
    "triggerType" TEXT NOT NULL,
    "capacityMinutes" INTEGER NOT NULL,
    "algorithmVersion" TEXT NOT NULL DEFAULT '1.0.0',
    "generatedAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "ScheduleVersion_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "ScheduleBlock" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "versionId" TEXT NOT NULL,
    "taskId" TEXT,
    "startTime" DATETIME NOT NULL,
    "endTime" DATETIME NOT NULL,
    "durationMinutes" INTEGER NOT NULL,
    "blockType" TEXT NOT NULL,
    "isCompleted" BOOLEAN NOT NULL DEFAULT false,
    "isLocked" BOOLEAN NOT NULL DEFAULT false,
    CONSTRAINT "ScheduleBlock_versionId_fkey" FOREIGN KEY ("versionId") REFERENCES "ScheduleVersion" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "ScheduleBlock_taskId_fkey" FOREIGN KEY ("taskId") REFERENCES "Task" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "DecisionLog" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "versionId" TEXT NOT NULL,
    "taskId" TEXT NOT NULL,
    "decisionType" TEXT NOT NULL,
    "priorityScore" REAL NOT NULL,
    "priorityComponentsJson" TEXT NOT NULL,
    "reasonCode" TEXT NOT NULL,
    "humanReadable" TEXT NOT NULL,
    CONSTRAINT "DecisionLog_versionId_fkey" FOREIGN KEY ("versionId") REFERENCES "ScheduleVersion" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "DecisionLog_taskId_fkey" FOREIGN KEY ("taskId") REFERENCES "Task" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "DisruptionEvent" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "userId" TEXT NOT NULL,
    "taskId" TEXT,
    "type" TEXT NOT NULL,
    "plannedMinutes" INTEGER NOT NULL,
    "actualMinutes" INTEGER NOT NULL,
    "detectedAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "DisruptionEvent_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE UNIQUE INDEX "UserConstraint_userId_key" ON "UserConstraint"("userId");

-- CreateIndex
CREATE INDEX "ScheduleBlock_versionId_startTime_idx" ON "ScheduleBlock"("versionId", "startTime");

-- CreateIndex
CREATE INDEX "ScheduleBlock_taskId_idx" ON "ScheduleBlock"("taskId");

-- CreateIndex
CREATE INDEX "DecisionLog_versionId_idx" ON "DecisionLog"("versionId");

-- CreateIndex
CREATE INDEX "DecisionLog_taskId_idx" ON "DecisionLog"("taskId");

-- CreateIndex
CREATE INDEX "DisruptionEvent_userId_idx" ON "DisruptionEvent"("userId");
