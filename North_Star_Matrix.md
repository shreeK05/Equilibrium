# Equilibrium - North Star Metric (NSM) Matrix

**Course:** Design Thinking & Product Lifecycle Management (DTPLM)
**Project Name:** Equilibrium - Student Workload Optimization Platform

---

## 1. The North Star Metric (NSM)
The North Star Metric is the single key performance indicator that best captures the core value Equilibrium delivers to its users.

**Our North Star Metric:** 
> **Weekly High-Focus Hours Achieved per Student**

### Why this NSM?
- **User Value:** Captures actual productive output (deep work) rather than vanity metrics like "time spent in app."
- **Business/Product Value:** Correlates directly with student retention, academic success, and overall well-being. If students achieve more high-focus hours, it means the Knapsack algorithm is effectively placing tasks in their peak energy windows.
- **Measurability:** Can be accurately tracked through completed blocks of "Medium/High" cognitive load tasks in the timeline.

---

## 2. The North Star Matrix (Metric Tree)

To achieve the North Star Metric, we break it down into leading (input) metrics that the product team can directly influence, and lagging (output) metrics that indicate overall business health.

### A. Input Metrics (Leading Indicators)
These are actionable metrics that drive the North Star Metric. Our product features directly influence these.

| Metric | Definition | How Equilibrium Impacts This |
| :--- | :--- | :--- |
| **Syllabus Import Rate** | % of users who successfully import at least one syllabus/calendar per week. | Streamlining PDF/ICS parsers reduces onboarding friction, giving the scheduler more data to work with. |
| **Schedule Generation Frequency** | Average number of times a user triggers the `ReschedulerPipeline` per week. | Easy "what-if" simulations and single-tap rescheduling encourage users to keep their timeline updated dynamically. |
| **Task Completion Rate** | % of scheduled task blocks marked as "Completed" on time. | The Sleep Shield and cognitive load balancing ensure tasks are realistic, preventing burnout and increasing completion. |
| **Peak-Energy Utilization** | % of high-cognitive tasks successfully mapped to the user's defined peak energy windows. | Core function of the Knapsack algorithm prioritizing hard tasks during optimal hours. |

### B. Output Metrics (Lagging Indicators)
These reflect the overarching success of the platform resulting from the North Star Metric.

| Metric | Definition | Business Value |
| :--- | :--- | :--- |
| **W1 / W4 Retention Rate** | % of users returning in Week 1 and Week 4 after signup. | Proves that the auto-generated schedules provide ongoing, recurring value throughout a semester. |
| **Burnout Reduction Score** | User-reported stress levels (or reduction in deferred/overdue tasks). | Validates the "Sleep Shield" and burnout prevention design pillars of the DTPLM problem statement. |
| **Team Share Engagement** | Number of unique views on read-only Team Share links. | Drives organic viral growth (PLG) as students share their study schedules with peers. |

---

## 3. Product Action Plan (Connecting Features to Metrics)

| Feature | Primary Metric Impacted | Expected Outcome |
| :--- | :--- | :--- |
| **Sleep Shield / Hard Constraints** | Task Completion Rate, Burnout Reduction | Higher trust in the schedule; fewer late-night impossible tasks. |
| **Syllabus Parser (PDF)** | Syllabus Import Rate | Drastically lowers time-to-value for new users during onboarding. |
| **Team Sharing (Read-Only)** | Team Share Engagement | Increases platform visibility within university cohorts. |
| **"What-If" Simulation** | Schedule Generation Frequency | Allows users to test massive tasks safely, increasing engagement with the scheduling engine. |

---
*Generated for DTPLM Project Documentation.*
