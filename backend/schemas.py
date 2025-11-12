from pydantic import BaseModel, EmailStr, ConfigDict, Field, HttpUrl
from datetime import datetime
from typing import Optional, List

# --- User Schemas ---

class UserCreate(BaseModel):
    email: EmailStr
    username: str
    name: str
    password: str

class UserInfo(BaseModel):
    id: int
    email: EmailStr
    username: str
    name: str
    model_config = ConfigDict(from_attributes=True)

class Token(BaseModel):
    access_token: str
    token_type: str

class EmailVerification(BaseModel):
    token: str

class ForgotPasswordRequest(BaseModel):
    email: EmailStr

class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str

# --- Plant Schemas ---
# [입력용] 사용자가 '내 식물'을 등록할 때 사용하는 스키마
class PlantCreate(BaseModel):
    name: str             # 사용자가 지어줄 애칭
    plant_master_id: int  # 참조할 식물 도감(PlantMaster)의 ID

# [출력용] API가 사용자에게 '내 식물' 정보를 보내줄 때 사용하는 스키마 (최종 수정)
class Plant(BaseModel):
    id: int
    name: str  # 사용자가 지어준 애칭
    species: str # 공식 학명

    # PlantMaster에서 가져온 대표 이미지 URL
    master_image_url: Optional[str] = None

    # --- ⬇️ PlantMaster의 상세 정보 추가 ⬇️ ---
    difficulty: Optional[str] = None
    light_requirement: Optional[str] = None
    watering_type: Optional[str] = None
    pet_safe: Optional[bool] = None
    # --- ⬆️ 추가 완료 ⬆️ ---

    # 물주기 알림 기능에 필요한 정보도 함께 보내줍니다.
    last_watered_at: Optional[datetime] = None
    is_notification_enabled: bool
    notification_time: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)

# --- Recommendation Schemas ---

# 추천 요청 시 프론트엔드로부터 받을 설문 데이터 양식
class SurveyRecommendRequest(BaseModel):
    place: str
    sunlight: str
    experience: str
    has_pets: bool = False
    desired_difficulty: Optional[str] = None
    limit: int = 10

# 추천 결과로 프론트엔드에 보내줄 개별 식물 데이터 양식
class RecommendItem(BaseModel):
    id: int
    name_ko: str
    image_url: Optional[str] = None
    difficulty: str
    light_requirement: str
    # 추천 점수와 이유를 함께 보내 UX를 개선합니다.
    score: float
    reasons: List[str] = []
    model_config = ConfigDict(from_attributes=True)

# --- Encyclopedia Schemas ---

class PlantMasterInfo(BaseModel):
    id: int
    name_ko: str
    name_en: Optional[str] = None
    species: str
    family: Optional[str] = None
    image_url: Optional[str] = None
    description: Optional[str] = None
    difficulty: str
    light_requirement: str
    watering_type: Optional[str] = None
    pet_safe: Optional[bool] = None
    tags: Optional[List] = None # JSON 필드는 보통 List나 Dict로 받습니다.
    model_config = ConfigDict(from_attributes=True)

# ⭐️ 관리자용 스키마
class PlantCreateRequest(BaseModel):
    species: str
    name_ko: str
    difficulty: str
    light_requirement: str
    watering_type: str
    pet_safe: bool
    family: Optional[str] = None


# media 업로드 응답 스키마
class MediaUploadResponse(BaseModel):
    image_id: int
    image_url: str
    thumb_url: str
    content_type: str
    width: int
    height: int
    
    model_config = ConfigDict(from_attributes=True)


# AI 진단 응답 스키마
class DiagnosisResult(BaseModel):
    label: str # 예: 'Tomato___Late_blight'
    score: float # 0.0 ~ 1.0

      # 추가: 분리/한글 매핑
    plant: str            # 예: "Potato"
    disease: str          # 예: "Early_Blight"
    plant_ko: str         # 예: "감자"
    disease_ko: str       # 예: "겹무늬병"
    label_ko: str         # 예: "감자 겹무늬병" 또는 "감자 정상"

class DiagnosisLLMRequest(BaseModel):
    image_url: str
    prompt_key: str = "default"

class DiagnosisLLMResponse(BaseModel):
    disease_key: str
    disease_ko: str
    reason_ko: str
    score: float
    severity: str

    guide: Optional["RemedyAdvice"] = None

class RemedyRequest(BaseModel):
    disease_key: str              # 예: "powdery_mildew"
    severity: Optional[str] = None  # "LOW" | "MEDIUM" | "HIGH" (없으면 자동 판단)
    plant_name: Optional[str] = None  # 식물명(선택)

class RemedyAdvice(BaseModel):
    disease_key: str
    disease_ko: str
    title_ko: str
    severity: str                  # 최종 판단된 심각도
    summary_ko: str
    immediate_actions: List[str]   # 바로 할 일(오늘)
    care_plan: List[str]           # 1~2주 관리 플랜
    prevention: List[str]          # 재발 방지
    caution: List[str]             # 주의사항(애완동물/약제 등)
    when_to_call_pro: List[str]    # 폐기/전문가 문의 기준

class ChatMessageOut(BaseModel):
    id: int
    thread_id: int
    role: str
    content: str
    image_url: Optional[str] = None
    provider_resp: Optional[dict] = None  # JSON이라면 dict
    tokens_in: Optional[int] = None
    tokens_out: Optional[int] = None
    created_at: datetime   # ← str → datetime 로 변경
    model_config = ConfigDict(from_attributes=True)

class ChatSendRequest(BaseModel):
    thread_id: Optional[int] = None
    message: str
    image_url: Optional[str] = None  # 이미지 프롬프트가 있으면 사용

class ChatSendResponse(BaseModel):
    thread_id: int
    assistant: ChatMessageOut

# --- Push Notification Schemas ---
class PushTokenUpdateRequest(BaseModel):
    push_token: str

# --- User Account Schemas ---
class UserDeleteResponse(BaseModel):
    message: str
    deleted_email: str

class VerifyCodeRequest(BaseModel):
    email: EmailStr
    code: str

class UserDeleteResponse(BaseModel):
    message: str
    deleted_email: str


# --- diary Scheams ---
# [신규] 일지 목록 조회 시 반환될 응답 스키마
class Diary(BaseModel):
    id: int
    plant_id: int
    created_at: datetime
    log_type: str # 👈 프론트엔드가 아이콘 구분을 위해 사용
    log_message: Optional[str] = None
    image_url: Optional[str] = None
    reference_id: Optional[int] = None

    model_config = ConfigDict(from_attributes=True)

# [신규] 사용자가 '수동 메모/사진'을 작성할 때 사용할 입력 스키마
class DiaryCreateManual(BaseModel):
    # 📝 NOTE 타입일 때 사용
    log_message: Optional[str] = None
    
    # 📸 PHOTO 타입일 때 사용 (우선 URL로 받음)
    # (추후 media.py와 연동하여 파일 업로드로 변경 가능)
    image_url: Optional[str] = None


# Community Models (게시판 기능)
class CommentBase(BaseModel):
    content: str

class CommentCreate(CommentBase):
    pass

class CommentUpdate(CommentBase):
    pass

# 댓글 조회 시 사용될 스키마 (작성자 정보 포함)
class Comment(CommentBase):
    id: int
    post_id: int
    created_at: datetime
    updated_at: datetime
    owner: UserInfo  # ⭐️ 작성자 정보(UserInfo)를 포함시켜 앱에서 "작성자: OOO" 표시 가능

    model_config = ConfigDict(from_attributes=True)

# --- Community: Post Schemas ---

class PostBase(BaseModel):
    title: str
    content: Optional[str] = None

class PostCreate(PostBase):
    pass

class PostUpdate(PostBase):
    title: Optional[str] = None
    content: Optional[str] = None

# 게시글 목록 조회 시 사용될 스키마 (댓글 미포함, 속도 향상)
class PostSimple(PostBase):
    id: int
    created_at: datetime
    updated_at: datetime
    owner: UserInfo # 작성자 정보
    
    model_config = ConfigDict(from_attributes=True)

# 게시글 상세 조회 시 사용될 스키마 (댓글 목록 포함)
class Post(PostBase):
    id: int
    created_at: datetime
    updated_at: datetime
    owner: UserInfo # 작성자 정보
    comments: List[Comment] = []  # ⭐️ 해당 게시글의 댓글 목록 포함

    model_config = ConfigDict(from_attributes=True)