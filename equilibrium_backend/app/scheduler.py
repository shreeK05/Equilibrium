from typing import List
from app import models

def calculate_available_capacity(sleep_hours: float, buffer_hours: float = 1.0, mandatory_hours: float = 0.0) -> float:
    """
    Calculates T_available = 24 - (T_sleep + T_buffer + T_mandatory)
    The sleep_hours constraint is hardcoded and mathematically unbreakable.
    """
    available_hours = 24.0 - (sleep_hours + buffer_hours + mandatory_hours)
    return max(0.0, available_hours)

def run_knapsack_solver(tasks: List[models.Task], available_hours: float):
    """
    A 0/1 Knapsack implementation to maximize priority_score without exceeding available_hours.
    We convert hours to minutes to use integer weights for the dynamic programming matrix.
    """
    capacity_mins = int(available_hours * 60)
    n = len(tasks)
    
    # DP table initialized to 0
    dp = [[0.0 for _ in range(capacity_mins + 1)] for _ in range(n + 1)]
    
    # Build the DP table
    for i in range(1, n + 1):
        task = tasks[i-1]
        weight_mins = int(task.estimated_hours * 60)
        value = task.priority_score
        
        for w in range(capacity_mins + 1):
            if weight_mins <= w:
                dp[i][w] = max(value + dp[i-1][w - weight_mins], dp[i-1][w])
            else:
                dp[i][w] = dp[i-1][w]
                
    # Backtrack to find which tasks were selected
    selected_tasks = []
    deferred_tasks = []
    w = capacity_mins
    
    for i in range(n, 0, -1):
        if dp[i][w] != dp[i-1][w]:
            selected_tasks.append(tasks[i-1])
            w -= int(tasks[i-1].estimated_hours * 60)
        else:
            deferred_tasks.append(tasks[i-1])
            
    return {
        "scheduled": selected_tasks,
        "deferred": deferred_tasks,
        "total_priority_achieved": dp[n][capacity_mins]
    }