"""
KaamSaaz — AI Chatbot Routes
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
    is_voice: bool = False

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
    "plumber":      ["plumber", "pipe", "tap", "nalka", "nal", "pani", "leak", "pani band", "nalki", "pipe leak", "toti", "tooti", "drain", "nala", "پلمبر", "نل", "پانی", "لیک"],
    "electrician":  ["electric", "bijli", "current", "wire", "socket", "switch", "light", "pankha", "fan", "board", "bulb", "tube light", "wiring", "فین", "بجلی", "پنکھا", "سوئچ", "الیکٹریشن"],
    "ac_mechanic":  ["ac", "a.c", "a/c", "air condition", "cooling", "thanda", "gas", "freon", "service", "ac service", "ac wala", "mechanic", "ٹھنڈا", "اے سی", "کولنگ", "thanda nahi kar raha"],
    "carpenter":    ["carpenter", "wood", "darwaza", "door", "furniture", "almari", "lakri", "lakdi", "bed", "sofa", "chair", "table", "kursi", "mez", "almira", "badhai", "بڑھئی", "لکڑی", "دروازہ", "الماری"],
    "painter":      ["paint", "rang", "wall", "deewar", "color", "colour", "rangan", "rogan", "distemper", "polish", "رنگ", "دیوار", "پینٹ"],
    "house_maid":   ["maid", "kaam wali", "cleaning", "safai", "safayi", "safayee", "saaf", "jharu", "pocha", "ghar ki safai", "dhona", "sweeper", "dusting", "ملازمہ", "کام والی", "صفائی", "گھر صاف"],
    "gardener":     ["garden", "mali", "plant", "tree", "lawn", "grass", "poda", "podhay", "podai", "poday", "bagh", "pauda", "ghas", "مالی", "باغ", "گھاس", "پودا"],
    "tutor":        ["tutor", "teacher", "ustad", "padhai", "study", "math", "science", "english", "parhai", "parhana", "academy", "school", "tuition", "sir", "madam", "استاد", "پڑھائی", "ٹیوٹر"],
    "beautician":   ["beauty", "makeup", "parlour", "mehendi", "waxing", "facial", "salon", "cutting", "mehndi", "threading", "bridal", "dulhan", "hair", "بیوٹیشن", "میک اپ", "مہندی"],
    "cook":         ["cook", "khana", "food", "bawarchi", "cooking", "chef", "roti", "salan", "pakana", "chawal", "biryani", "daawat", "kitchen", "باورچی", "کھانا", "کوک"],
    "generator":    ["generator", "genset", "backup", "light chali gayi", "gen", "janretar", "janrator", "جنریٹر", "بجلی چلی گئی"],
    "welder":       ["weld", "loha", "iron", "gate", "jali", "grill", "steel", "tanki", "welder", "ویلڈر", "لوہا"],
    "tiler":        ["tile", "floor", "mezzanine", "bathroom tiles", "farash", "farsh", "pathar", "marbal", "tail", "tailan", "tailain", "tiler", "marble", "ٹائل", "فرش", "ٹائل لگانا"],
}

TIME_PATTERNS = [
    r'\b(\d{1,2})\s*(am|pm|بجے|صبح|شام|رات)\b',
    r'\b(kal|aaj|parso|parson|tomorrow|today|kal subah|kal subha|aaj raat)\b',
    r'\b(subah|subha|dophar|dopahar|shaam|raat|morning|afternoon|evening|night)\b',
    r'\b(\d{1,2}:\d{2})\b',
    r'\b(abhi|now|jaldi|asap|فوری|ابھی)\b',
]

GREETING_PATTERNS = [
    r'^(hi|hello|hey|salam|assalam|aoa|السلام علیکم|ہیلو|ہائے)\b',
    r'^(kya hal|how are|kaise ho|ٹھیک)\b',
]


# ── Intent extraction helpers ─────────────────────────────────────────────────

def has_date(text: str) -> bool:
    lower = text.lower()
    date_words = ["kal", "tomorrow", "parso", "parson", "day after tomorrow", "aaj", "today"]
    if any(re.search(rf"\b{word}\b", lower) for word in date_words):
        return True
    if re.search(r'\b\d{1,2}[/-]\d{1,2}\b', lower):
        return True
    return False

def has_time_of_day(text: str) -> bool:
    lower = text.lower()
    time_words = [
        "subah", "subha", "dophar", "dopahar", "shaam", "raat", "morning", "afternoon", "evening", "night",
        "abhi", "now", "jaldi", "asap", "fauri", "فوری", "ابھی"
    ]
    if any(re.search(rf"\b{word}\b", lower) for word in time_words):
        return True
    if re.search(r'\b\d{1,2}\s*(am|pm|بجے|صبح|شام|رات)\b', lower):
        return True
    if re.search(r'\b\d{1,2}:\d{2}\b', lower):
        return True
    return False

def detect_service(text: str) -> Optional[str]:
    lower = text.lower()
    # Guard against obvious irrelevant queries
    irrelevant_signals = ["recipe", "weather", "joke", "song", "movie", "news", "what is the difference", "explain"]
    if any(sig in lower for sig in irrelevant_signals):
        return None
    for service, keywords in SERVICE_KEYWORDS.items():
        for kw in keywords:
            if kw.lower() in lower:
                return service
    return None

def detect_time(text: str) -> Optional[str]:
    lower = text.lower()
    
    # Combined date + time of day patterns
    combined_patterns = [
        r'\b(kal|aaj|parso|parson|tomorrow|today|day after tomorrow)\s+(at\s+)?(subah|subha|dophar|dopahar|shaam|raat|morning|afternoon|evening|night|\d{1,2}\s*(am|pm|بجے|صبح|شام|رات)|\d{1,2}:\d{2})\b',
        r'\b(subah|subha|dophar|dopahar|shaam|raat|morning|afternoon|evening|night|\d{1,2}\s*(am|pm|بجے|صبح|شام|رات)|\d{1,2}:\d{2})\s+(of\s+)?(kal|aaj|parso|parson|tomorrow|today|day after tomorrow)\b',
    ]
    for pattern in combined_patterns:
        m = re.search(pattern, lower)
        if m:
            start, end = m.span()
            return text[start:end]
            
    # Fallback to individual patterns
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

    # Frontend sends "[Voice Message Received]" marker (no base64 audio over chat endpoint)
    if msg == "[Voice Message Received]" or req.is_voice:
        is_voice = True
        if lang == "ur":
            reply = "آپ کا وائس میسج مل گیا! ابھی آواز کی پہچان دستیاب نہیں۔ براہ کرم اپنا مسئلہ ٹائپ کریں — جیسے: 'مجھے پلمبر چاہیے'"
        else:
            reply = "Aap ka voice message mila! Abhi voice transcription available nahi. Kindly apna masla type karein — jaise: 'Mujhe plumber chahiye'"
        return AIChatResponse(
            reply=reply,
            action="chat",
            user_transcription="[Voice Message]"
        )

    # Legacy: raw base64 audio payload (fallback)
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
                    if lang == "ur":
                        reply = "معذرت، میں آپ کا وائس میسج نہیں سن سکا۔ برائے مہربانی اپنا مسئلہ ٹائپ کر کے بتائیں۔"
                    else:
                        reply = "Aap ka voice message mila lekin main use sun nahi saka. Kindly type kr k batayein ap ko kis service ki zaroorat hai."
                    return AIChatResponse(
                        reply=reply,
                        action="chat",
                        user_transcription="[Voice Message]"
                    )
        except Exception as e:
            print(f"[AI Chat] Voice message transcription failed: {e}")
            if lang == "ur":
                reply = "معذرت، میں آپ کا وائس میسج نہیں سن سکا۔ برائے مہربانی اپنا مسئلہ ٹائپ کر کے بتائیں۔"
            else:
                reply = "Aap ka voice message mila lekin main use sun nahi saka. Kindly type kr k batayein ap ko kis service ki zaroorat hai."
            return AIChatResponse(
                reply=reply,
                action="chat",
                user_transcription="[Voice Message]"
            )

    # ── 1. Detect service from conversation history + current message ──────────
    full_context = " ".join([t.text for t in history if t.role == "user"] + [msg])
    service = detect_service(full_context)
    time_hint = detect_time(full_context)
    time_is_exact = False
    if time_hint:
        time_is_exact = has_time_of_day(time_hint)

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
                "Wa Alaikum Assalam! I'm your KaamSaaz assistant. 😊\n\n"
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

    time_hint_display = time_hint if time_is_exact else ("Date specified but need exact time of day" if time_hint else "not mentioned yet")

    gemini_prompt = f"""You are KaamSaaz, a smart home services booking assistant for Pakistan.
You ONLY help with booking home services (plumber, electrician, AC mechanic, carpenter, painter, house maid, gardener, tutor, beautician, cook, welder, tiler, generator mechanic).

RULES:
1. Reply in the SAME language the customer uses (Roman Urdu, Urdu, or English).
2. If the customer specifies a problem or service but has NOT given a specific time of day (e.g. they only said "kal", "parso", "tomorrow", or "aaj") → you MUST ask for the exact time of day (e.g. "kal kis time?", "parso kis time?"). DO NOT proceed with booking and do NOT include [READY_TO_BOOK] until they provide an exact time/hour/time of day (e.g. morning, 10 AM, subha, shaam).
3. If you identified the service AND they gave a specific time of day (e.g. "kal subha", "today at 5 PM", "parso shaam") → reply saying you'll find providers now. End reply with: [READY_TO_BOOK]
4. If the question is NOT about home services → politely say you only handle home service bookings.
5. Keep replies SHORT (max 3-4 lines). Be warm and helpful.
6. Do NOT make up prices or provider names.
7. Important mappings: "kal" = tomorrow, "parso" = day after tomorrow, "subha" = morning, "shaam" = evening.
8. Response language preference: {"Urdu" if lang == "ur" else "Match customer's language"}

Detected service so far: {service or "not yet detected"}
Detected time so far: {time_hint_display}

Conversation so far:
{history_text}

Customer now says: {msg}

Your reply:"""

    try:
        gemini_reply = await generate_text(gemini_prompt)
        gemini_reply = gemini_reply.strip()
    except Exception as e:
        print(f"[AI Chat] Gemini API failed (Credits exhausted?): {e}")
        # Rule-based fallback if API fails
        if not service:
            gemini_reply = (
                "آپ کو کس سروس کی ضرورت ہے؟ (جیسے پلمبر، الیکٹریشن)" if lang == "ur"
                else "Ap ko kis service ki zaroorat hai? (e.g., Plumber, Electrician)"
            )
        elif service and not time_is_exact:
            service_label = get_service_label(service, lang)
            if time_hint:
                gemini_reply = (
                    f"ٹھیک ہے، {time_hint} کو کس وقت؟ برائے مہربانی وقت کنفرم کر دیں۔" if lang == "ur"
                    else f"Theek hai, {time_hint} kis time? Kindly exact time confirm kr dein."
                )
            else:
                gemini_reply = (
                    f"آپ کو {service_label} کی ضرورت ہے۔ برائے مہربانی وقت کنفرم کر دیں۔" if lang == "ur"
                    else f"Ap ko {service} ki zaroorat hai kindly time confirm kr dein."
                )
        else:
            # We have both service and time
            gemini_reply = "[READY_TO_BOOK]"

    # ── 4. Check if Gemini says ready to book ─────────────────────────────────
    ready_to_book = "[READY_TO_BOOK]" in gemini_reply
    
    # Enforce programmatic safeguard: do NOT book unless time is exact and service is detected
    if not service or not time_is_exact:
        ready_to_book = False
        
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
