from fastapi import FastAPI
from routers import auth
# import models
# from database import engine

# models.Base.metadata.create_all(bind=engine) # DB 담당자 작업 완료 후 주석 해제

app = FastAPI()

app.include_router(auth.router)

@app.get("/")
def read_root():
    return {"message": "Welcome to Green Day API"}