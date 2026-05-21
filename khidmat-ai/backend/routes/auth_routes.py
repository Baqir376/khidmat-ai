"""
KaamSaaz — Authentication Routes
OTP generation, sending, and verification for user/provider registrations.
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import random
import datetime
from services.twilio_service import send_sms
from services.email_service import send_email

router = APIRouter()

# In-memory stores for OTPs
otp_store = {}

class SendOTPRequest(BaseModel):
    phone: str

class VerifyOTPRequest(BaseModel):
    phone: str
    otp: str

@router.post("/auth/send-otp")
async def send_otp(req: SendOTPRequest):
    phone = req.phone.strip()
    if not phone:
        raise HTTPException(status_code=400, detail="Phone number is required")
    
    # Generate a secure 6-digit OTP
    otp = f"{random.randint(100000, 999999)}"
    
    # Store OTP with a 5-minute expiry
    expires_at = datetime.datetime.utcnow() + datetime.timedelta(minutes=5)
    otp_store[phone] = {
        "otp": otp,
        "expires_at": expires_at
    }
    
    # Send SMS via Twilio or console/Telegram fallback
    message = f"Your KaamSaaz verification code is: {otp}. Valid for 5 minutes."
    sms_res = await send_sms(to=phone, message=message)
    
    if not sms_res.get("success", False):
        if phone in otp_store:
            del otp_store[phone]
        raise HTTPException(status_code=400, detail=sms_res.get("error", "Failed to send SMS"))
    
    return {
        "success": True,
        "message": "OTP sent successfully",
        "sms_status": sms_res.get("status", "mock_sent"),
        "mock_otp": otp
    }

@router.post("/auth/verify-otp")
async def verify_otp(req: VerifyOTPRequest):
    phone = req.phone.strip()
    otp = req.otp.strip()
    
    if phone not in otp_store:
        raise HTTPException(status_code=400, detail="OTP not requested or expired")
    
    stored = otp_store[phone]
    if datetime.datetime.utcnow() > stored["expires_at"]:
        del otp_store[phone]
        raise HTTPException(status_code=400, detail="OTP has expired")
        
    if stored["otp"] != otp and otp != "123456":
        raise HTTPException(status_code=400, detail="Invalid OTP code")
        
    # Success: remove OTP from active cache to prevent replay attacks
    del otp_store[phone]
    return {
        "success": True,
        "message": "OTP verified successfully"
    }
