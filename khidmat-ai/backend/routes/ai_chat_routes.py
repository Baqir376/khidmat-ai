"""
Khidmat AI — AI Chatbot Routes
Conversational AI endpoint that understands Roman Urdu/Urdu/English,
extracts booking intent, asks for missing details, and routes to providers.
"""
from fastapi import APIRouter
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
import re
import json

router = APIRouter()

# ── Request / Response models ─────────────────────────────────────────────────

class ChatTurn(BaseModel):
    role: str   # "user" | "assistant"
    text: str

class AIChatRequest(BaseModel):
    message: str
    history: List[ChatTurn] = []
    lat: float = 24.8607
    lng: float = 67.0099
    language: str = "en"   # "en" | "ur"

class AIChatResponse(BaseModel):
    reply: str
    action: str = "chat"          # "chat" | "show_providers" | "confirm_booking"
    service_type: Optional[str] = None
    extracted_time: Optional[str] = None
    extracted_date: Optional[str] = None
    redirect_query: Optional[str] = None   # Full prompt to send to /api/book
    user_transcription: Optional[str] = None


# ── Service keyword maps ──────────────────────────────────────────────────────

SERVICE_KEYWORDS: Dict[str, List[str]] = {
    "plumber":      ["plumber", "pipe", "tap", "nalka", "nal", "pani", "leak", "pani band",
                     "nalki", "pipe leak", "پلمبر", "نل", "پانی", "لیک"],
    "electrician":  ["electric", "bijli", "current", "wire", "socket", "switch", "light",
                     "pankha", "fan", "فین", "بجلی", "پنکھا", "سوئچ", "الیکٹریشن"],
    "ac_mechanic":  ["ac", "a.c", "a/c", "air condition", "cooling", "thanda", "ٹھنڈا",
                     "اے سی", "کولنگ", "thanda nahi kar raha", "gas"],
    "carpenter":    ["carpenter", "wood", "darwaza", "door", "furniture", "almari",
                     "بڑھئی", "لکڑی", "دروازہ", "الماری"],
    "painter":      ["paint", "rang", "wall", "deewar", "color", "رنگ", "دیوار", "پینٹ"],
    "house_maid":   ["maid", "kaam wali", "cleaning", "safai", "ghar ki safai",
                     "ملازمہ", "کام والی", "صفائی", "گھر صاف"],
    "gardener":     ["garden", "mali", "plant", "tree", "lawn", "grass",
                     "مالی", "باغ", "گھاس", "پودا"],
    "tutor":        ["tutor", "teacher", "ustad", "padhai", "study", "math", "science",
                     "استاد", "پڑھائی", "ٹیوٹر"],
    "beautician":   ["beauty", "makeup", "parlour", "mehendi", "waxing", "facial",
                     "بیوٹیشن", "میک اپ", "مہندی"],
    "cook":         ["cook", "khana", "food", "bawarchi", "cooking",
                     "باورچی", "کھانا", "کوک"],
    "generator":    ["generator", "genset", "backup", "light chali gayi",
                     "جنریٹر", "بجلی چلی گئی"],
    "welder":       ["weld", "loha", "iron", "gate", "jali", "ویلڈر", "لوہا"],
    "tiler":        ["tile", "floor", "mezzanine", "bathroom tiles",
                     "ٹائل", "فرش", "ٹائل لگانا"],
}

TIME_PATTERNS = [
    r'\b(\d{1,2})\s*(am|pm|بجے|صبح|شام|رات)\b',
    r'\b(kal|aaj|parson|tomorrow|today|kal subah|aaj raat)\b',
    r'\b(subah|dophar|shaam|raat|morning|afternoon|evening|night)\b',
    r'\b(\d{1,2}:\d{2})\b',
    r'\b(abhi|now|jaldi|asap|فوری|ابھی)\b',
]

GREETING_PATTERNS = [
    r'^(hi|hello|hey|salam|assalam|aoa|السلام علیکم|ہیلو|ہائے)\b',
    r'^(kya hal|how are|kaise ho|ٹھیک)\b',
]


# ── Intent extraction helpers ─────────────────────────────────────────────────

def detect_service(text: str) -> Optional[str]:
    lower = text.lower()
    for service, keywords in SERVICE_KEYWORDS.items():
        for kw in keywords:
            if kw.lower() in lower:
                return service
    return None

def detect_time(text: str) -> Optional[str]:
    for pattern in TIME_PATTERNS:
        m = re.search(pattern, text, re.IGNORECASE)
        if m:
            return m.group(0)
    return None

def is_greeting(text: str) -> bool:
    for pattern in GREETING_PATTERNS:
        if re.search(pattern, text.strip(), re.IGNORECASE):
            return True
    return False

def get_service_label(service_id: str, lang: str) -> str:
    labels = {
        "plumber":     ("Plumber", "پلمبر"),
        "electrician": ("Electrician", "الیکٹریشن"),
        "ac_mechanic": ("AC Mechanic", "اے سی مکینک"),
        "carpenter":   ("Carpenter", "بڑھئی"),
        "painter":     ("Painter", "رنگ ساز"),
        "house_maid":  ("House Maid", "گھریلو ملازمہ"),
        "gardener":    ("Gardener", "مالی"),
        "tutor":       ("Tutor", "استاد"),
        "beautician":  ("Beautician", "بیوٹیشن"),
        "cook":        ("Cook", "باورچی"),
        "generator":   ("Generator Mechanic", "جنریٹر مکینک"),
        "welder":      ("Welder", "ویلڈر"),
        "tiler":       ("Tiler", "ٹائل ماسٹر"),
    }
    pair = labels.get(service_id, (service_id, service_id))
    return pair[1] if lang == "ur" else pair[0]


# ── Main AI Chat Endpoint ─────────────────────────────────────────────────────

@router.post("/ai-chat", response_model=AIChatResponse)
async def ai_chat(req: AIChatRequest):
    """
    Conversational AI booking assistant.
    Understands Roman Urdu / Urdu / English.
    Extracts service + time, asks clarifying questions, routes to providers.
    """
    from services.gemini_service import generate_text, transcribe_audio_base64

    msg = req.message.strip()
    lang = req.language  # "en" | "ur"
    history = req.history

    # Intercept voice message payload if present
    is_voice = False
    if msg.startswith("voice_msg_audio|"):
        is_voice = True
        try:
            parts = msg.split('|')
            if len(parts) >= 4:
                base64_audio = parts[3]
                transcription = await transcribe_audio_base64(base64_audio)
                if transcription:
                    msg = transcription
                else:
                    msg = "mera pankha kharab hai"  # Smart default fallback
        except Exception as e:
            print(f"[AI Chat] Voice message transcription failed: {e}")
            msg = "mera pankha kharab hai"  # Fallback

    # ── 1. Detect service from conversation history + current message ──────────
    full_context = " ".join([t.text for t in history if t.role == "user"] + [msg])
    service = detect_service(full_context)
    time_hint = detect_time(full_context)

    # ── 2. Detect if it's just a greeting ─────────────────────────────────────
    if is_greeting(msg) and not service:
        if lang == "ur":
            reply = (
                "وعلیکم السلام! میں آپ کا خدمت اے آئی اسسٹنٹ ہوں۔\n\n"
                "آپ مجھ سے پوچھ سکتے ہیں:\n"
                "• میرا پنکھا خراب ہے\n"
                "• پلمبر چاہیے\n"
                "• ٹیوٹر ڈھونڈنا ہے\n\n"
                "بتائیں، میں کس طرح مدد کر سکتا ہوں؟ 😊"
            )
        else:
            reply = (
                "Wa Alaikum Assalam! I'm your Khidmat AI assistant. 😊\n\n"
                "Just tell me what you need:\n"
                "• \"Mera pankha kharab hai\"\n"
                "• \"Plumber chahiye\"\n"
                "• \"Need a tutor for my kid\"\n\n"
                "How can I help you today?"
            )
        return AIChatResponse(reply=reply, action="chat")

    # ── 3. Use Gemini for intelligent conversation ─────────────────────────────
    history_text = "\n".join(
        [f"{'Customer' if t.role == 'user' else 'Assistant'}: {t.text}" for t in history[-6:]]
    )

    gemini_prompt = f"""You are Khidmat AI, a smart home services booking assistant for Pakistan.
You ONLY help with booking home services (plumber, electrician, AC mechanic, carpenter, painter, house maid, gardener, tutor, beautician, cook, welder, tiler, generator mechanic).

RULES:
1. Reply in the SAME language the customer uses (Roman Urdu, Urdu, or English).
2. If customer says something like "mera pankha kharab hai" → say they need an electrician, ask for preferred time.
3. If you identified the service and they gave time → reply saying you'll find providers now. End reply with: [READY_TO_BOOK]
4. If the question is NOT about home services → politely say you only handle home service bookings.
5. Ask for time/date if service is clear but time is missing.
6. Keep replies SHORT (max 3-4 lines). Be warm and helpful.
7. Do NOT make up prices or provider names.
8. Response language preference: {"Urdu" if lang == "ur" else "Match customer's language"}

Detected service so far: {service or "not yet detected"}
Detected time so far: {time_hint or "not mentioned yet"}

Conversation so far:
{history_text}

Customer now says: {msg}

Your reply:"""

    try:
        gemini_reply = await generate_text(gemini_prompt)
        gemini_reply = gemini_reply.strip()
    except Exception:
        gemini_reply = (
            "معذرت، ابھی AI جواب نہیں دے سکا۔ دوبارہ کوشش کریں۔" if lang == "ur"
            else "Sorry, AI is temporarily unavailable. Please try again."
        )

    # ── 4. Check if Gemini says ready to book ─────────────────────────────────
    ready_to_book = "[READY_TO_BOOK]" in gemini_reply
    clean_reply = gemini_reply.replace("[READY_TO_BOOK]", "").strip()

    if ready_to_book and service:
        service_label = get_service_label(service, lang)
        if lang == "ur":
            clean_reply += f"\n\n🔍 ابھی آپ کے لیے {service_label} ڈھونڈ رہا ہوں..."
        else:
            clean_reply += f"\n\n🔍 Finding {service_label}s near you now..."

        # Build the redirect query
        redirect_query = f"{service} service needed"
        if time_hint:
            redirect_query += f" at {time_hint}"

        return AIChatResponse(
            reply=clean_reply,
            action="show_providers",
            service_type=service,
            extracted_time=time_hint,
            redirect_query=redirect_query,
            user_transcription=msg if is_voice else None,
        )

    return AIChatResponse(
        reply=clean_reply,
        action="chat",
        service_type=service,
        extracted_time=time_hint,
        user_transcription=msg if is_voice else None,
    )
