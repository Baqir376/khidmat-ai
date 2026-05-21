"""
KaamSaaz — Configuration
All environment variables and settings centralized here.
API keys are loaded from .env and NEVER hardcoded.
"""
import os
from dotenv import load_dotenv

load_dotenv()


class Config:
    """Application configuration loaded from environment variables."""

    # Google Gemini
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")
    GEMINI_MODEL: str = os.getenv("GEMINI_MODEL", "gemini-2.0-flash")

    # Google Maps
    GOOGLE_MAPS_API_KEY: str = os.getenv("GOOGLE_MAPS_API_KEY", "")

    # Firebase (Legacy)
    FIREBASE_PROJECT_ID: str = os.getenv("FIREBASE_PROJECT_ID", "")
    FIREBASE_CREDENTIALS_PATH: str = os.getenv(
        "FIREBASE_CREDENTIALS_PATH", "firebase-credentials.json"
    )

    # Supabase
    SUPABASE_URL: str = os.getenv("SUPABASE_URL", "")
    SUPABASE_KEY: str = os.getenv("SUPABASE_KEY", "")

    # Twilio
    TWILIO_ACCOUNT_SID: str = os.getenv("TWILIO_ACCOUNT_SID", "")
    TWILIO_AUTH_TOKEN: str = os.getenv("TWILIO_AUTH_TOKEN", "")
    TWILIO_WHATSAPP_NUMBER: str = os.getenv(
        "TWILIO_WHATSAPP_NUMBER", "whatsapp:+14155238886"
    )
    TWILIO_PHONE_NUMBER: str = os.getenv("TWILIO_PHONE_NUMBER", "")

    # Blockchain (Polygon Amoy Testnet)
    POLYGON_RPC_URL: str = os.getenv(
        "POLYGON_RPC_URL", "https://rpc-amoy.polygon.technology"
    )
    WALLET_PRIVATE_KEY: str = os.getenv("WALLET_PRIVATE_KEY", "")

    # JazzCash Sandbox
    JAZZCASH_MERCHANT_ID: str = os.getenv("JAZZCASH_MERCHANT_ID", "")
    JAZZCASH_PASSWORD: str = os.getenv("JAZZCASH_PASSWORD", "")

    # Telegram
    TELEGRAM_BOT_TOKEN: str = os.getenv("TELEGRAM_BOT_TOKEN", "")

    # Cloudinary
    CLOUDINARY_CLOUD_NAME: str = os.getenv("CLOUDINARY_CLOUD_NAME", "")
    CLOUDINARY_API_KEY: str = os.getenv("CLOUDINARY_API_KEY", "")

    # SendGrid
    SENDGRID_API_KEY: str = os.getenv("SENDGRID_API_KEY", "")

    # App Settings
    APP_NAME: str = "KaamSaaz"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = os.getenv("DEBUG", "true").lower() == "true"
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "8000"))

    # Default location (Karachi center)
    DEFAULT_LAT: float = 24.8607
    DEFAULT_LNG: float = 67.0099
    DEFAULT_CITY: str = "Karachi"


config = Config()
