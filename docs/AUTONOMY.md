# Equilibrium Autonomy Philosophy

The primary directive of Equilibrium is:
**"The user defines what needs to be done. Equilibrium decides when to do it."**

## What the User Controls
The student provides raw scheduling ingredients:
1. **Tasks**: Title, Deadline, Estimate (Time required).
2. **Priorities**: Academic weight, Cognitive load.
3. **Constraints**: Minimum sleep, Sleep windows (Sleep Shield).
4. **Commitments**: Fixed classes, meetings, or exams.
5. **Preferences**: Peak energy windows.

## What Equilibrium Controls
Equilibrium operates a deterministic operations-research pipeline (0/1 Knapsack + Placement Engine) to output:
1. **Task Selection**: Which tasks actually fit within the week before their deadlines.
2. **Task Deferral**: Which tasks mathematically cannot fit without violating the Sleep Shield or deadlines.
3. **Task Placement**: The exact chronological order of work blocks.
4. **Task Splitting**: Breaking a 4-hour task into multiple 1.5-hour chunks to fit around classes.
5. **Rescheduling**: Reacting to early finishes, overruns, or skipped sessions by dynamically re-solving the entire puzzle.

## Why Deterministic?
Equilibrium does **not** use LLMs or generative AI to build schedules.
1. **Explainability**: Every deferred task has a `DecisionLog` proving why it was deferred (e.g., `CAPACITY_EXCEEDED`).
2. **Reproducibility**: The exact same inputs yield the exact same schedule.
3. **Safety**: Hard constraints (Sleep Shield) are mathematically guaranteed via intersection validation. A generative model could hallucinate a study session at 3 AM. Equilibrium cannot.
