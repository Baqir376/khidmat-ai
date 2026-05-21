"""
KaamSaaz — Pydantic Data Models
All request/response schemas and data structures.
"""
from pydantic import BaseModel, Field
from typing import Optional, Literal
from datetime import datetime


# ============================================================
# USER MODELS
# ============================================================

class UserBase(BaseModel):
    phone: str
    name: str
    email: Optional[str] = None
    role: Literal["citizen", "provider", "admin"] = "citizen"
    avatar_url: Optional[str] = None
    preferred_language: Literal["ur", "en", "roman_ur", "sd"] = "roman_ur"
    trusted_contact_phone: Optional[str] = None
    fcm_token: Optional[str] = None
    whatsapp_verified: bool = False
    biometric_enabled: bool = False
    gender: Optional[Literal["male", "female", "prefer_not_to_say"]] = None
    womens_safety_mode: bool = False
    total_bookings: int = 0


class UserCreate(UserBase):
    pass


class UserResponse(UserBase):
    id: str
    created_at: Optional[datetime] = None


# ============================================================
# SERVICE TYPE MODELS
# ============================================================

class ServiceType(BaseModel):
    id: str
    name_en: str
    name_ur: str
    name_roman_ur: str
    name_sd: str
    icon: str
    base_rate_min: int
    base_rate_max: int
    peak_multiplier: float
    category: Literal[
        "electrical", "plumbing", "hvac", "education",
        "beauty", "construction", "other"
    ]


# ============================================================
# PROVIDER MODELS
# ============================================================

class ProviderBase(BaseModel):
    user_id: str = ""
    service_type_id: str
    name_en: str
    name_ur: str
    bio_en: str
    bio_ur: str
    experience_years: int
    cnic_hash: str = ""
    cnic_verified: bool = False
    gender: Literal["male", "female"]
    lat: float
    lng: float
    area_name: str
    city: str = "Karachi"
    coverage_radius_km: float = 10.0
    hourly_rate: int
    is_available: bool = True
    is_emergency_available: bool = False
    trust_score: float = 50.0
    trust_badge: Literal["Bronze", "Silver", "Gold", "Elite"] = "Bronze"
    total_jobs: int = 0
    cancellation_rate: float = 0.0
    avg_response_time_minutes: float = 15.0
    rating: float = 4.0
    total_reviews: int = 0
    portfolio_urls: list[str] = []
    instagram_handle: Optional[str] = None
    blockchain_address: Optional[str] = None
    insurance_active: bool = False
    welfare_score: float = 50.0
    skill_badges: list[str] = []


class ProviderCreate(ProviderBase):
    pass


class ProviderResponse(ProviderBase):
    id: str
    created_at: Optional[datetime] = None


# ============================================================
# BOOKING MODELS
# ============================================================

class BookingBase(BaseModel):
    citizen_id: str
    provider_id: str
    service_type_id: str
    status: Literal[
        "pending", "accepted", "en_route", "in_progress",
        "completed", "cancelled", "disputed"
    ] = "pending"
    original_input: str = ""
    input_language: str = "roman_ur"
    input_type: Literal["text", "voice", "whatsapp", "telegram", "photo", "iot"] = "text"
    service_address: str = ""
    service_lat: float = 0.0
    service_lng: float = 0.0
    service_area: str = ""
    scheduled_date: str = ""
    scheduled_time: str = ""
    estimated_duration_minutes: int = 60
    quoted_price: int = 0
    final_price: Optional[int] = None
    fair_price_min: int = 0
    fair_price_max: int = 0
    price_negotiated: bool = False
    negotiation_log: list[dict] = []
    match_score: float = 0.0
    agent_reasoning: dict = {}
    counterfactual_reasoning: str = ""
    provider_eta_minutes: Optional[int] = None
    safety_link_token: str = ""
    safety_contact_notified: bool = False
    selfie_verified: bool = False
    blockchain_tx_hash: Optional[str] = None
    blockchain_confirmed: bool = False
    google_calendar_event_id: Optional[str] = None
    jazzcash_transaction_id: Optional[str] = None
    escrow_active: bool = False
    pdf_receipt_url: Optional[str] = None
    dispute_status: Optional[Literal[
        "open", "reschedule_offered", "refund_offered", "escalated"
    ]] = None


class BookingCreate(BaseModel):
    """What the user sends to create a booking."""
    user_input: str
    lat: float = 24.8607
    lng: float = 67.0099
    womens_safety_mode: bool = False
    input_type: Literal["text", "voice", "whatsapp", "telegram", "photo", "iot"] = "text"
    image_base64: Optional[str] = None


class BookingResponse(BookingBase):
    id: str
    created_at: Optional[datetime] = None
    agent_traces: list[dict] = []
    actions_taken: list[str] = []


# ============================================================
# AGENT TRACE MODELS
# ============================================================

class AgentTrace(BaseModel):
    id: str = ""
    booking_id: Optional[str] = None
    session_id: str
    agent_name: str
    step_number: int
    input_data: dict = {}
    output_data: dict = {}
    tool_calls: list[dict] = []
    reasoning_text: str = ""
    duration_ms: int = 0
    status: Literal["running", "success", "error", "fallback"] = "running"
    created_at: Optional[datetime] = None


# ============================================================
# REVIEW MODELS
# ============================================================

class ReviewCreate(BaseModel):
    provider_id: str
    booking_id: str
    rating: float = Field(ge=1.0, le=5.0)
    review_text: str


class ReviewResponse(ReviewCreate):
    id: str
    citizen_id: str
    sentiment_score: float = 0.0
    sentiment_label: Literal[
        "very_positive", "positive", "neutral", "negative", "very_negative"
    ] = "neutral"
    is_fake_suspected: bool = False
    created_at: Optional[datetime] = None


# ============================================================
# API RESPONSE MODELS
# ============================================================

class AgentPipelineResponse(BaseModel):
    """Full response from the agent pipeline."""
    success: bool
    booking: Optional[BookingResponse] = None
    top_providers: list[dict] = []
    agent_traces: list[AgentTrace] = []
    total_duration_ms: int = 0
    counterfactual: str = ""
    error: Optional[str] = None


class ProviderSearchResponse(BaseModel):
    """Response for provider search/nearby queries."""
    providers: list[ProviderResponse] = []
    total: int = 0
    service_type: str = ""
