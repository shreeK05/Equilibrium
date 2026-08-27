from sqlalchemy import Column, Integer, String, Float, ForeignKey, JSON
from app.database import Base

class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    email = Column(String, unique=True, index=True)
    min_sleep_hours = Column(Float, default=7.0) # The non-negotiable constraint

class Task(Base):
    __tablename__ = "tasks"
    
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, index=True)
    owner_id = Column(Integer, ForeignKey("users.id"))
    estimated_hours = Column(Float)
    priority_score = Column(Float)
    status = Column(String, default="pending")

class DecisionLog(Base):
    __tablename__ = "decision_log"
    
    id = Column(Integer, primary_key=True, index=True)
    task_id = Column(Integer, ForeignKey("tasks.id"))
    reason_code = Column(String)
    priority_components_json = Column(JSON) # Powers the explainability panel