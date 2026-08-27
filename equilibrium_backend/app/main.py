from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
from app import models, schemas, scheduler
from app.database import engine, get_db

# Create the database tables
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Equilibrium API")

@app.get("/")
def health_check():
    return {"status": "Equilibrium Core is online. Sleep constraint active."}

@app.post("/users/", response_model=schemas.User)
def create_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    db_user = models.User(name=user.name, email=user.email, min_sleep_hours=user.min_sleep_hours)
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

@app.post("/tasks/{user_id}", response_model=schemas.Task)
def create_task(user_id: int, task: schemas.TaskCreate, db: Session = Depends(get_db)):
    # Verify user exists
    db_user = db.query(models.User).filter(models.User.id == user_id).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")
        
    db_task = models.Task(**task.model_dump(), owner_id=user_id)
    db.add(db_task)
    db.commit()
    db.refresh(db_task)
    return db_task

@app.get("/tasks/list/{user_id}")
def get_user_tasks(user_id: int, db: Session = Depends(get_db)):
    return db.query(models.Task).filter(models.Task.owner_id == user_id).all()

@app.post("/schedule/generate/{user_id}")
def generate_schedule(user_id: int, db: Session = Depends(get_db)):
    # 1. Fetch the user to get their strict sleep constraint
    db_user = db.query(models.User).filter(models.User.id == user_id).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # 2. Fetch all pending tasks for this user
    pending_tasks = db.query(models.Task).filter(
        models.Task.owner_id == user_id, 
        models.Task.status == "pending"
    ).all()
    
    if not pending_tasks:
        return {"message": "No pending tasks to schedule. Create a new task first!"}
        
    # 3. Calculate today's available capacity
    available_hours = scheduler.calculate_available_capacity(
        sleep_hours=db_user.min_sleep_hours,
        buffer_hours=1.0  # 1 hour default buffer
    )
    
    # 4. Run the 0/1 Knapsack Engine
    result = scheduler.run_knapsack_solver(pending_tasks, available_hours)
    
    # 5. Log Scheduled Tasks
    for task in result["scheduled"]:
        task.status = "scheduled"
        log = models.DecisionLog(
            task_id=task.id,
            reason_code="FIT_CAPACITY",
            priority_components_json={
                "priority_score": task.priority_score, 
                "hours_used": task.estimated_hours,
                "explanation": f"Fit within today's {available_hours}h capacity."
            }
        )
        db.add(log)

    # 6. Log Deferred Tasks (The Sleep Protectors)
    for task in result["deferred"]:
        task.status = "deferred"
        log = models.DecisionLog(
            task_id=task.id,
            reason_code="SLEEP_PROTECTED",
            priority_components_json={
                "priority_score": task.priority_score, 
                "hours_required": task.estimated_hours,
                "explanation": f"Deferred. Adding this {task.estimated_hours}h task would violate your {db_user.min_sleep_hours}h sleep constraint."
            }
        )
        db.add(log)
        
    # 7. Commit everything to PostgreSQL
    db.commit()
    
    return {"message": "Schedule locked. Decisions logged to database."}

@app.get("/tasks/explain/{task_id}")
def explain_decision(task_id: int, db: Session = Depends(get_db)):
    # Fetch the most recent decision log for this specific task
    log = db.query(models.DecisionLog).filter(models.DecisionLog.task_id == task_id).order_by(models.DecisionLog.id.desc()).first()
    
    if not log:
        raise HTTPException(status_code=404, detail="No decision log found for this task.")
        
    return {
        "task_id": log.task_id,
        "reason_code": log.reason_code,
        "the_math": log.priority_components_json
    }