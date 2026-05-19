"""
Khidmat AI — Twilio Service
WhatsApp messages, SMS, and voice calls via Twilio API.
Falls back to console logging when Twilio credentials are not configured.
"""
from config import config
from typing import Optional

_twilio_client = None

import os
import requests

try:
    from twilio.rest import Client

    if config.TWILIO_ACCOUNT_SID and config.TWILIO_AUTH_TOKEN:
        _twilio_client = Client(config.TWILIO_ACCOUNT_SID, config.TWILIO_AUTH_TOKEN)
        print("[Twilio] Connected")
    else:
        print("[Twilio] No credentials — using console logging")
except Exception as e:
    print(f"[Twilio] [Warning] Init failed ({e}) - using console logging")

TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
TELEGRAM_CHAT_ID = os.getenv("TELEGRAM_CHAT_ID")
if TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID:
    print("[Telegram] Active - Free alternative to Twilio loaded!")


async def send_whatsapp(to: str, message: str) -> dict:
    """Send WhatsApp message via Twilio or Telegram fallback. Always returns fast."""
    import asyncio

    if not to.startswith("whatsapp:"):
        to = f"whatsapp:{to}"

    if _twilio_client:
        try:
            msg = _twilio_client.messages.create(
                body=message,
                from_=config.TWILIO_WHATSAPP_NUMBER,
                to=to,
            )
            return {"success": True, "sid": msg.sid, "status": msg.status, "to": to}
        except Exception as e:
            print(f"[Twilio WhatsApp Error] {e} - Falling back to Mock")

    # Telegram fallback — non-blocking, 3s timeout
    if TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID:
        try:
            url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
            await asyncio.wait_for(
                asyncio.to_thread(
                    requests.post, url,
                    json={"chat_id": TELEGRAM_CHAT_ID, "text": message},
                    timeout=3
                ),
                timeout=4.0
            )
            print(f"[Telegram] Sent: {message[:60]}...")
        except Exception:
            pass  # Don't block on Telegram failure

    # Console mock — instant
    print(f"[WhatsApp MOCK] To:{to} | {message[:80]}")
    return {"success": True, "sid": f"MOCK_{to[-4:]}", "status": "mock_sent", "to": to}


def normalize_phone_number(phone: str) -> str:
    """Normalizes phone number to E.164 format, default for Pakistani phone numbers."""
    cleaned = "".join(c for c in phone if c.isdigit() or c == "+")
    if cleaned.startswith("03") and len(cleaned) == 11:
        return "+92" + cleaned[1:]
    elif cleaned.startswith("3") and len(cleaned) == 10:
        return "+92" + cleaned
    elif cleaned.startswith("92") and not cleaned.startswith("+"):
        return "+" + cleaned
    if not cleaned.startswith("+"):
        # Default fallback to prepend + if missing
        return "+" + cleaned
    return cleaned


async def send_sms(to: str, message: str) -> dict:
    """Send SMS via Twilio with Telegram real-time fallback."""
    import asyncio
    
    to_normalized = normalize_phone_number(to)
    
    if _twilio_client and config.TWILIO_PHONE_NUMBER:
        try:
            msg = _twilio_client.messages.create(
                body=message,
                from_=config.TWILIO_PHONE_NUMBER,
                to=to_normalized,
            )
            return {"success": True, "sid": msg.sid, "status": msg.status}
        except Exception as e:
            print(f"[Twilio SMS Error] {e}")
            # Continuing to fallback (Telegram / Mock) so development is not blocked
            pass
    # Telegram fallback for real-time developer testing
    if TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID and TELEGRAM_CHAT_ID != "your_chat_id":
        try:
            url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
            await asyncio.wait_for(
                asyncio.to_thread(
                    requests.post, url,
                    json={"chat_id": TELEGRAM_CHAT_ID, "text": f"📱 *[SMS to {to_normalized}]*\n{message}"},
                    timeout=3
                ),
                timeout=4.0
            )
            print(f"[Telegram SMS Fallback] Sent: {message[:60]}...")
            return {"success": True, "sid": "TELEGRAM_SMS", "status": "telegram_sent"}
        except Exception as e:
            print(f"[Telegram SMS Fallback Error] {e}")
            
    print(f"[SMS MOCK] To: {to_normalized} | Message: {message[:100]}")
    return {"success": True, "sid": "MOCK_SMS", "status": "mock_sent"}


async def send_booking_confirmation_whatsapp(
    phone: str,
    booking_id: str,
    service_type: str,
    provider_name: str,
    scheduled_date: str,
    scheduled_time: str,
    quoted_price: int,
    safety_link: Optional[str] = None,
) -> dict:
    """Send structured booking confirmation via WhatsApp."""
    message = (
        f"*Khidmat AI -- Booking Confirmed*\n\n"
        f"Booking ID: {booking_id}\n"
        f"Service: {service_type}\n"
        f"Provider: {provider_name}\n"
        f"Date: {scheduled_date}\n"
        f"Time: {scheduled_time}\n"
        f"Rate: Rs {quoted_price}\n"
    )

    if safety_link:
        message += f"\nSafety Link: {safety_link}\n"
        message += "Share this link with your trusted contact.\n"

    message += "\n_Powered by Khidmat AI_"

    return await send_whatsapp(phone, message)


async def send_provider_job_request_whatsapp(
    phone: str,
    booking_id: str,
    service_type: str,
    citizen_name: str,
    area: str,
    scheduled_time: str,
    quoted_price: int,
) -> dict:
    """Send job request notification to provider via WhatsApp."""
    message = (
        f"*Khidmat AI -- Naya Kaam*\n\n"
        f"Booking: {booking_id}\n"
        f"Service: {service_type}\n"
        f"Customer: {citizen_name}\n"
        f"Area: {area}\n"
        f"Time: {scheduled_time}\n"
        f"Rate: Rs {quoted_price}\n\n"
        f"Reply 'ACCEPT' ya 'REJECT' karein.\n"
        f"\n_Khidmat AI_"
    )

    return await send_whatsapp(phone, message)


async def send_reminder_whatsapp(
    phone: str,
    provider_name: str,
    service_type: str,
    scheduled_time: str,
    minutes_before: int = 60,
) -> dict:
    """Send appointment reminder via WhatsApp."""
    message = (
        f"*Khidmat AI -- Reminder*\n\n"
        f"Aapka appointment {minutes_before} minute baad hai:\n"
        f"{provider_name} ({service_type})\n"
        f"{scheduled_time}\n\n"
        f"_Khidmat AI_"
    )

    return await send_whatsapp(phone, message)


async def make_voice_call(
    to: str,
    twiml_url: str,
) -> dict:
    """Initiate a voice call via Twilio (for AI voice agent)."""
    if _twilio_client and config.TWILIO_PHONE_NUMBER:
        try:
            call = _twilio_client.calls.create(
                url=twiml_url,
                to=to,
                from_=config.TWILIO_PHONE_NUMBER,
            )
            return {"success": True, "sid": call.sid, "status": call.status}
        except Exception as e:
            return {"success": False, "error": str(e)}
    else:
        print(f"[Voice MOCK] Calling {to}")
        return {"success": True, "sid": "MOCK_CALL", "status": "mock_initiated"}
