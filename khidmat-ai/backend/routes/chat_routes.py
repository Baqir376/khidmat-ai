from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime

from services.firebase_service import create_document, query_collection, get_document

import re

router = APIRouter()

class ChatMessage(BaseModel):
    booking_id: str
    sender_id: str
    text: str

# Vulgarity / Profanity list covering English and Roman Urdu patterns
VULGAR_PATTERNS = [
    # English
    r"fuck\w*", r"shit\w*", r"asshole\w*", r"bitch\w*", r"bastard\w*", r"cunt\w*", r"dick\w*", r"pussy\w*", r"wanker\w*", r"motherfuck\w*",
    # Roman Urdu / Urdu Abuses
    r"bhenchod\w*", r"behenchod\w*", r"madarchod\w*", r"penchod\w*", r"bhosdike\w*", r"chutiya\w*", r"gand\w*", r"bund\w*", r"harami\w*", 
    r"kutta\w*", r"saala\w*", r"sala\w*", r"kamina\w*", r"kamine\w*", r"bhadva\w*", r"bhadwa\w*", r"loda\w*", r"lora\w*", r"gandu\w*",
    r"\bbc\b", r"\bmc\b"
]

def _censor_string(s: str) -> str:
    moderated = s
    for pattern_str in VULGAR_PATTERNS:
        pattern = re.compile(pattern_str, re.IGNORECASE)
        def censor(match):
            return "*" * len(match.group(0))
        moderated = pattern.sub(censor, moderated)
    return moderated

def moderate_text(text: str) -> str:
    """Scan and sanitize text by replacing vulgar words with asterisks, preserving voice message binary data."""
    if text.startswith("voice_msg_audio|"):
        # Format: voice_msg_audio|duration|waveforms|base64_audio
        parts = text.split("|", 3)
        if len(parts) >= 4:
            # Do NOT moderate base64 audio!
            return f"voice_msg_audio|{parts[1]}|{parts[2]}|{parts[3]}"
        return text
    
    if text.startswith("voice_msg|"):
        # Format: voice_msg|duration|waveforms|transcription
        parts = text.split("|", 3)
        if len(parts) >= 4:
            # Moderate ONLY the transcription part
            moderated_transcription = _censor_string(parts[3])
            return f"voice_msg|{parts[1]}|{parts[2]}|{moderated_transcription}"
        return text

    return _censor_string(text)

@router.post("/")
async def send_message(message: ChatMessage):
    """Save a chat message to the messages collection with moderation filtering."""
    booking = await get_document("bookings", message.booking_id)
    if booking and booking.get("status") in ["completed", "cancelled"]:
        raise HTTPException(
            status_code=400,
            detail=f"Chat has been closed because this booking is {booking.get('status')}."
        )
    
    sanitized_text = moderate_text(message.text)
    doc_id = await create_document("messages", {
        "booking_id": message.booking_id,
        "sender_id": message.sender_id,
        "text": sanitized_text,
        "timestamp": datetime.utcnow().isoformat()
    })
    return {"success": True, "message_id": doc_id, "text": sanitized_text}

@router.get("/{booking_id}")
async def get_messages(booking_id: str):
    """Get all messages for a booking."""
    messages = await query_collection("messages")
    
    # Filter by booking_id
    filtered = []
    for m in messages:
        if m.get("booking_id") == booking_id:
            filtered.append(m)
            
    # Sort by timestamp ascending
    filtered.sort(key=lambda x: x.get("timestamp", ""))
    return {"messages": filtered}
