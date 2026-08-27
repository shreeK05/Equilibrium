from pydantic import BaseModel
from typing import Optional

# --- Task Schemas ---
class TaskBase(BaseModel):
    title: str
    estimated_hours: float
    priority_score: float

class TaskCreate(TaskBase):
    pass

class Task(TaskBase):
    id: int
    owner_id: int
    status: str

    class Config:
        from_attributes = True

# --- User Schemas ---
class UserBase(BaseModel):
    name: str
    email: str
    min_sleep_hours: Optional[float] = 7.0

class UserCreate(UserBase):
    pass

class User(UserBase):
    id: int

    class Config:
        from_attributes = True