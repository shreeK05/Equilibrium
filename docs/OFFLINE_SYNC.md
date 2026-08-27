# Equilibrium Offline Sync & Connectivity State

Equilibrium explicitly splits functionality into **Offline-Capable** and **Online-Dependent** domains. No external integrations are claimed to work offline. The source of truth for the scheduling algorithm is ALWAYS the server.

## 1. Offline-Capable Features (Device-Local via Hive)
These features function seamlessly with 0% network connectivity.
- **Read-Only Schedule Timeline**: The user can open the app and view their current Day/Night schedule.
- **Read-Only Task List**: The user can view task details, priorities, and explanations (loaded from the latest cached `DecisionLog`).
- **Task State Mutations**: The user can mark tasks as COMPLETED or OVERRUN.
- **Task Creation**: The user can create new tasks.
- **Sync Queue**: Any local mutations (creates, completes, overruns) are stored in a local SQLite/Hive `PendingSyncQueue`. 

## 2. Online-Dependent Features
These features explicitly show a "Network Required" state if offline.
- **Google Calendar Sync**: Cannot fetch or push OAuth events.
- **Syllabus PDF Parsing**: Uploading and extracting NLP candidates requires the backend pipeline.
- **Team Share Generation**: Generating cryptographic URLs requires the server.
- **Schedule Re-Optimization (The Engine)**: Because the DP Knapsack algorithm runs on the Node.js backend, a user cannot generate a *new* schedule while offline. 
  - *UX Fallback*: If a user marks an overrun offline, the UI notes "Pending Sync: Schedule will rebalance when connected."

## 3. Synchronization Pipeline
1. Network restored event detected.
2. Flutter client flushes `PendingSyncQueue` to the server in a single transactional batch.
3. If mutations included disruptions or new tasks, the server automatically triggers the Scheduling Engine.
4. Server responds with the newest `ScheduleVersion`.
5. Client overwrites the local Hive cache and animates the new schedule UI.
