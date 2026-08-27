# Equilibrium Database Design

This document details the Prisma relational schema designed to enforce constraints, task durations, and deterministic scheduling.

## 1. Entities & Relationships

### User & Constraints
```prisma
model User {
  id               String           @id @default(uuid())
  email            String           @unique
  passwordHash     String
  timezone         String           @default("UTC")
  createdAt        DateTime         @default(now())
  
  constraint       UserConstraint?
  tasks            Task[]
  scheduleVersions ScheduleVersion[]
  disruptions      DisruptionEvent[]
}

model UserConstraint {
  id                    String  @id @default(uuid())
  userId                String  @unique
  minSleepHours         Float   // Application enforces >= 7.0
  sleepStart            String  // e.g., "23:30"
  sleepEnd              String  // e.g., "07:00"
  bufferMinutes         Int     @default(30)
  peakEnergyWindowsJson String  // e.g., [{"start":"09:00","end":"12:00"}]
  
  user                  User    @relation(fields: [userId], references: [id])
}
```

### Academic Workload (Tasks)
```prisma
model Task {
  id               String   @id @default(uuid())
  userId           String
  title            String
  
  // Duration Tracking
  estimateMinutes  Int      // Initial user estimate
  completedMinutes Int      @default(0) // Time permanently marked done
  // remainingMinutes is computed dynamically: max(0, estimateMinutes - completedMinutes)

  deadline         DateTime
  academicWeight   Float    @default(0.5) // [0.0 - 1.0]
  teamImpactWeight Float    @default(0.0) // [0.0 - 1.0]
  cognitiveLoad    String   @default("MEDIUM") // LOW, MEDIUM, HIGH
  
  deferralCount    Int      @default(0) // Increments if unscheduled or partially scheduled
  status           String   @default("PENDING") // PENDING, IN_PROGRESS, COMPLETED, ARCHIVED
  createdAt        DateTime @default(now())

  user             User            @relation(fields: [userId], references: [id])
  blocks           ScheduleBlock[]
  logs             DecisionLog[]
}
```

### Scheduler Output & Versioning
```prisma
model ScheduleVersion {
  id               String   @id @default(uuid())
  userId           String
  triggerType      String   // MANUAL, EOD, DISRUPTION, IMPORT
  capacityMinutes  Int      // The exact capacity calculated for this run
  algorithmVersion String   @default("1.0.0")
  generatedAt      DateTime @default(now())

  user             User            @relation(fields: [userId], references: [id])
  blocks           ScheduleBlock[]
  decisionLogs     DecisionLog[]
}

model ScheduleBlock {
  id               String   @id @default(uuid())
  versionId        String
  taskId           String?  // Nullable for non-task blocks (e.g. SLEEP, FIXED)
  startTime        DateTime
  endTime          DateTime
  durationMinutes  Int      // Mathematical length of this chunk
  blockType        String   // TASK, SLEEP, FIXED, BUFFER
  isCompleted      Boolean  @default(false)

  version          ScheduleVersion @relation(fields: [versionId], references: [id], onDelete: Cascade)
  task             Task?           @relation(fields: [taskId], references: [id])

  @@index([versionId, startTime])
}
```

### Audit & Explainability
```prisma
model DecisionLog {
  id                     String   @id @default(uuid())
  versionId              String
  taskId                 String
  decisionType           String   // FULLY_SCHEDULED, PARTIALLY_SCHEDULED, DEFERRED
  priorityScore          Float
  priorityComponentsJson String   // { "academic": 0.5, "urgency": 2.1, "debt": 0.0 }
  reasonCode             String   // e.g., "FRAGMENTED_CAPACITY", "CAPACITY_EXCEEDED"
  humanReadable          String   // e.g., "Partially Scheduled: 2h placed, 2h deferred."
  
  version                ScheduleVersion @relation(fields: [versionId], references: [id], onDelete: Cascade)
  task                   Task            @relation(fields: [taskId], references: [id])
}

model DisruptionEvent {
  id               String   @id @default(uuid())
  userId           String
  taskId           String?
  type             String   // OVERRUN, EARLY_COMPLETION, MISSED, NEW_FIXED_EVENT
  plannedMinutes   Int
  actualMinutes    Int
  detectedAt       DateTime @default(now())

  user             User     @relation(fields: [userId], references: [id])
}
```
