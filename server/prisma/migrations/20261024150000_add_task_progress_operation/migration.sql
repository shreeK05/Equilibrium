-- CreateTable
CREATE TABLE "TaskProgressOperation" (
    "id" TEXT NOT NULL,
    "operationId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "taskId" TEXT NOT NULL,
    "payloadHash" TEXT NOT NULL,
    "responseBodyJson" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "TaskProgressOperation_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "TaskProgressOperation_operationId_key" ON "TaskProgressOperation"("operationId");

-- CreateIndex
CREATE INDEX "TaskProgressOperation_userId_taskId_idx" ON "TaskProgressOperation"("userId", "taskId");

-- CreateIndex
CREATE INDEX "TaskProgressOperation_operationId_idx" ON "TaskProgressOperation"("operationId");

-- AddForeignKey
ALTER TABLE "TaskProgressOperation" ADD CONSTRAINT "TaskProgressOperation_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TaskProgressOperation" ADD CONSTRAINT "TaskProgressOperation_taskId_fkey" FOREIGN KEY ("taskId") REFERENCES "Task"("id") ON DELETE CASCADE ON UPDATE CASCADE;
