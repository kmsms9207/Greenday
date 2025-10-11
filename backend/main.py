from fastapi import FastAPI
import models
import database
from routers import auth, plants, recommendations, identify, encyclopedia, diagnose_v2, diagnose_v3, media, remedy, admin 

# 수정: database.engine을 직접 사용하도록 변경
models.Base.metadata.create_all(bind=database.engine)

app = FastAPI(
    title="Green Day API",
    description="개인 맞춤 반려식물 추천 및 통합 관리 시스템 API 명세서",
    version="0.4.0"
)

app.include_router(admin.router)
app.include_router(auth.router)
app.include_router(plants.router)
app.include_router(recommendations.router)
app.include_router(identify.router)
app.include_router(encyclopedia.router) 
app.include_router(diagnose_v2.router)
app.include_router(diagnose_v3.router)
app.include_router(media.router)
app.include_router(remedy.router)


@app.get("/")
def read_root():
    return {"message": "Welcome to Green Day API Server"}