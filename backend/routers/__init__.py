from fastapi import APIRouter
from .auth import router as auth_router
from .plants import router as plants_router
from .identify import router as identify_router
from .encyclopedia import router as encyclopedia_router  
# from .recommendation import router as recommendations_router  
# from .catalog import router as catalog_router

api_router = APIRouter()
api_router.include_router(auth_router)
api_router.include_router(plants_router)
api_router.include_router(identify_router)
api_router.include_router(encyclopedia.router)  
# api_router.include_router(recommendations.router)  
# api_router.include_router(catalog_router)
