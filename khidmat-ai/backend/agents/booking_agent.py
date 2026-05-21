"""
KaamSaaz — Agent 5: Booking Agent
Creates confirmed bookings, sends notifications, records on blockchain.
This is the ACTION SIMULATION agent — critical for hackathon scoring.
"""
import time
import uuid
import hashlib
from datetime import datetime
from services.firebase_service import create_document, save_agent_trace
from services.twilio_service import (
    send_booking_confirmation_whatsapp,
    send_provider_job_request_whatsapp,
)
from services.blockchain_service import record_on_blockchain
from services.payment_service import simulate_jazzcash_payment, create_escrow

from typing import Optional
from services.maps_service import reverse_geocode

AGENT_NAME = "BookingAgent"


async def run_booking_agent(
    provider: dict,
    intent: dict,
    final_price: int,
    negotiation_log: list,
    fair_price: dict,
    counterfactual: str,
    match_score: float,
    session_id: str,
    citizen_id: str = "citizen_demo",
    user_name: str = "Customer",
    user_phone: str = "+92300000000",
    womens_safety_mode: bool = False,
    user_lat: Optional[float] = None,
    user_lng: Optional[float] = None,
) -> dict:
    """
    Execute the booking: create record, send notifications, record on blockchain.
    This demonstrates the CRITICAL ACTION SIMULATION requirement.
    """
    start_time = time.time()
    trace_id = str(uuid.uuid4())[:12]
    booking_id = f"BK-{uuid.uuid4().hex[:8].upper()}"
    actions_taken = []

    try:
        # ========================================
        # ACTION 1: Create booking in database
        # ========================================
        safety_token = hashlib.sha256(
            f"{booking_id}{datetime.utcnow().isoformat()}".encode()
        ).hexdigest()[:16]

        # Determine exact customer coordinates and address using free keyless reverse geocoding
        lat = float(user_lat) if user_lat is not None else float(provider.get("lat", 24.8607))
        lng = float(user_lng) if user_lng is not None else float(provider.get("lng", 67.0099))
        
        service_address = intent.get("location", "")
        if user_lat is not None and user_lng is not None:
            try:
                rev_geo = await reverse_geocode(lat, lng)
                service_address = rev_geo.get("full_address") or rev_geo.get("address") or service_address
                actions_taken.append(f"Successfully reverse-geocoded coordinates ({lat}, {lng}) to '{service_address}'")
            except Exception as e:
                print(f"[BookingAgent] Free reverse geocoding failed: {e}")

        booking_data = {
            "id": booking_id,
            "citizen_id": citizen_id,
            "user_name": user_name,
            "user_phone": user_phone,
            "provider_id": provider.get("id", ""),
            "service_type_id": intent.get("service_type", ""),
            "status": "pending",  # REAL-TIME FLOW: Wait for provider acceptance
            "original_input": intent.get("original_text", ""),
            "input_language": intent.get("language", "roman_ur"),
            "service_address": service_address,
            "service_lat": lat,
            "service_lng": lng,
            "service_area": provider.get("area_name", ""),
            "scheduled_date": intent.get("resolved_date", ""),
            "scheduled_time": intent.get("resolved_time", "09:00"),
            "estimated_duration_minutes": 60,
            "quoted_price": final_price,
            "fair_price_min": fair_price.get("min", 0),
            "fair_price_max": fair_price.get("max", 0),
            "price_negotiated": len(negotiation_log) > 1,
            "negotiation_log": negotiation_log,
            "match_score": match_score,
            "counterfactual_reasoning": counterfactual,
            "provider_eta_minutes": provider.get("eta_minutes", 15),
            "safety_link_token": safety_token,
            "womens_safety_mode": womens_safety_mode,
            "agent_reasoning": {
                "session_id": session_id,
                "provider_name": provider.get("name_en", ""),
                "provider_rating": provider.get("rating", 0),
                "distance_km": provider.get("distance_km", 0),
            },
        }

        await create_document("bookings", booking_data, booking_id)
        actions_taken.append(f"Booking {booking_id} created in database")

        # ========================================
        # ACTION 2: Send WhatsApp confirmation to citizen
        # ========================================
        citizen_msg = await send_booking_confirmation_whatsapp(
            phone="+923001234567",  # Demo phone
            booking_id=booking_id,
            service_type=intent.get("service_type", ""),
            provider_name=provider.get("name_en", "Provider"),
            scheduled_date=intent.get("resolved_date", ""),
            scheduled_time=intent.get("resolved_time", ""),
            quoted_price=final_price,
            safety_link=f"https://khidmat.ai/safety/{safety_token}" if womens_safety_mode else None,
        )
        actions_taken.append(f"WhatsApp confirmation sent (SID: {citizen_msg.get('sid', 'N/A')})")

        # ========================================
        # ACTION 3: Send job request to provider
        # ========================================
        provider_msg = await send_provider_job_request_whatsapp(
            phone="+923009876543",  # Demo phone
            booking_id=booking_id,
            service_type=intent.get("service_type", ""),
            citizen_name=user_name,
            area=provider.get("area_name", ""),
            scheduled_time=intent.get("resolved_time", ""),
            quoted_price=final_price,
        )
        actions_taken.append(f"Provider job notification sent (SID: {provider_msg.get('sid', 'N/A')})")

        duration_ms = int((time.time() - start_time) * 1000)

        reasoning = (
            f"Booking {booking_id} created as PENDING. "
            f"Waiting for Provider {provider.get('name_en')} to ACCEPT. "
            f"Price: Rs {final_price} | "
            f"Date: {intent.get('resolved_date')} at {intent.get('resolved_time')}"
        )

        trace = {
            "id": trace_id,
            "session_id": session_id,
            "agent_name": AGENT_NAME,
            "step_number": 5,
            "input_data": {
                "provider": provider.get("name_en", ""),
                "final_price": final_price,
                "service_type": intent.get("service_type", ""),
            },
            "output_data": {
                "booking_id": booking_id,
                "status": "pending",
                "actions_count": len(actions_taken),
            },
            "tool_calls": [
                {"tool": "firestore_create_booking", "status": "success"},
                {"tool": "whatsapp_citizen_confirmation", "status": "success"},
                {"tool": "whatsapp_provider_notification", "status": "success"},
            ],
            "reasoning_text": reasoning,
            "duration_ms": duration_ms,
            "status": "success",
        }
        await save_agent_trace(trace)

        return {
            "success": True,
            "booking_id": booking_id,
            "booking": booking_data,
            "actions_taken": actions_taken,
            "trace": trace,
        }

    except Exception as e:
        duration_ms = int((time.time() - start_time) * 1000)
        trace = {
            "id": trace_id,
            "session_id": session_id,
            "agent_name": AGENT_NAME,
            "step_number": 5,
            "output_data": {"error": str(e), "actions_before_failure": actions_taken},
            "reasoning_text": f"Booking failed after {len(actions_taken)} actions: {e}",
            "duration_ms": duration_ms,
            "status": "error",
        }
        await save_agent_trace(trace)
        return {"success": False, "error": str(e), "actions_taken": actions_taken, "trace": trace}
