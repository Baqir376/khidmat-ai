"""
KaamSaaz — Agent 6: FollowUp Agent
Handles post-booking automation: reminders, status updates, reviews, disputes.
"""
import time
import uuid
from services.twilio_service import send_reminder_whatsapp, send_whatsapp
from services.gemini_service import generate_json
from services.firebase_service import (
    save_agent_trace, update_document, create_document
)

AGENT_NAME = "FollowUpAgent"


async def run_followup_agent(
    booking: dict,
    provider: dict,
    session_id: str,
    action: str = "schedule_reminders",
) -> dict:
    """
    Execute follow-up actions for a confirmed booking.
    Actions: schedule_reminders, check_status, request_review, handle_dispute
    """
    start_time = time.time()
    trace_id = str(uuid.uuid4())[:12]
    actions_taken = []

    try:
        booking_id = booking.get("id", "")
        provider_name = provider.get("name_en", "Provider")
        service_type = booking.get("service_type_id", "")
        scheduled_time = booking.get("scheduled_time", "09:00")
        scheduled_date = booking.get("scheduled_date", "")

        if action == "schedule_reminders":
            # Send 1-hour-before reminder
            reminder_1h = await send_reminder_whatsapp(
                phone="+923001234567",
                provider_name=provider_name,
                service_type=service_type,
                scheduled_time=f"{scheduled_date} {scheduled_time}",
                minutes_before=60,
            )
            actions_taken.append(f"1-hour reminder scheduled (SID: {reminder_1h.get('sid', 'N/A')})")

            # Send 15-min reminder
            reminder_15m = await send_reminder_whatsapp(
                phone="+923001234567",
                provider_name=provider_name,
                service_type=service_type,
                scheduled_time=f"{scheduled_date} {scheduled_time}",
                minutes_before=15,
            )
            actions_taken.append(f"15-min reminder scheduled (SID: {reminder_15m.get('sid', 'N/A')})")

            # Notify provider about upcoming job
            provider_reminder = await send_whatsapp(
                to="+923009876543",
                message=(
                    f"⏰ *KaamSaaz — Job Reminder*\n\n"
                    f"Aapka kaam {scheduled_time} par hai.\n"
                    f"Service: {service_type}\n"
                    f"Booking: {booking_id}\n\n"
                    f"Waqt par pohanchein! _KaamSaaz_ 🤖"
                ),
            )
            actions_taken.append(f"Provider reminder sent (SID: {provider_reminder.get('sid', 'N/A')})")

        elif action == "request_review":
            # Generate review request message
            review_msg = await send_whatsapp(
                to="+923001234567",
                message=(
                    f"⭐ *KaamSaaz — Review Request*\n\n"
                    f"{provider_name} ki service kaisi rahi?\n"
                    f"1-5 stars mein rating dein:\n\n"
                    f"Reply karein: RATE 1/2/3/4/5\n"
                    f"Ya apna review likhein.\n\n"
                    f"_Aapki feedback se providers behtar hote hain!_ 🤖"
                ),
            )
            actions_taken.append(f"Review request sent (SID: {review_msg.get('sid', 'N/A')})")

        elif action == "check_status":
            # Simulate status check with provider
            status_msg = await send_whatsapp(
                to="+923009876543",
                message=(
                    f"📊 *KaamSaaz — Status Check*\n\n"
                    f"Booking {booking_id} ka kya status hai?\n"
                    f"Reply: EN_ROUTE / ARRIVED / IN_PROGRESS / COMPLETED\n\n"
                    f"_KaamSaaz_ 🤖"
                ),
            )
            actions_taken.append(f"Status check sent to provider")

        elif action == "handle_dispute":
            # Use Gemini to analyze dispute and suggest resolution
            prompt = f"""A customer has a dispute about booking {booking_id}.
Service: {service_type}
Provider: {provider_name}
Price: Rs {booking.get('quoted_price', 0)}

Suggest a fair resolution in Roman Urdu.
Return JSON with: resolution_type (refund/reschedule/partial_refund), 
message_to_citizen, message_to_provider, reasoning"""

            resolution = await generate_json(prompt)
            actions_taken.append(f"Dispute resolution generated: {resolution.get('resolution_type', 'pending')}")

            # Update booking status
            await update_document("bookings", booking_id, {
                "dispute_status": resolution.get("resolution_type", "open"),
            })
            actions_taken.append("Booking dispute status updated")

        elif action == "completion_confirmation":
            # Mark booking as completed
            await update_document("bookings", booking_id, {
                "status": "completed",
            })
            actions_taken.append("Booking marked as completed")

            # Send completion message
            completion_msg = await send_whatsapp(
                to="+923001234567",
                message=(
                    f"✅ *KaamSaaz — Service Complete*\n\n"
                    f"Booking {booking_id} mukammal ho gaya!\n"
                    f"Provider: {provider_name}\n"
                    f"Service: {service_type}\n\n"
                    f"Shukria KaamSaaz use karne ka! 🙏\n"
                    f"_Rating dena na bhoolein!_ ⭐"
                ),
            )
            actions_taken.append(f"Completion confirmation sent")

        duration_ms = int((time.time() - start_time) * 1000)

        reasoning = (
            f"FollowUp action '{action}' executed for booking {booking_id}. "
            f"Actions taken: {len(actions_taken)}. "
            f"Provider: {provider_name} | Service: {service_type}."
        )

        trace = {
            "id": trace_id,
            "session_id": session_id,
            "agent_name": AGENT_NAME,
            "step_number": 6,
            "input_data": {"booking_id": booking_id, "action": action},
            "output_data": {"actions_count": len(actions_taken), "action_type": action},
            "tool_calls": [
                {"tool": f"followup_{action}", "status": "success", "count": len(actions_taken)},
            ],
            "reasoning_text": reasoning,
            "duration_ms": duration_ms,
            "status": "success",
        }
        await save_agent_trace(trace)

        return {
            "success": True,
            "action": action,
            "actions_taken": actions_taken,
            "trace": trace,
        }

    except Exception as e:
        duration_ms = int((time.time() - start_time) * 1000)
        trace = {
            "id": trace_id,
            "session_id": session_id,
            "agent_name": AGENT_NAME,
            "step_number": 6,
            "output_data": {"error": str(e)},
            "reasoning_text": f"FollowUp failed: {e}",
            "duration_ms": duration_ms,
            "status": "error",
        }
        await save_agent_trace(trace)
        return {"success": False, "error": str(e), "trace": trace}
