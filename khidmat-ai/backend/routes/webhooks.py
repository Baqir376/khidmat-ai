"""
Khidmat AI — Messaging Webhooks
WhatsApp (Twilio) and Telegram webhook endpoints.
"""
from fastapi import APIRouter, Request, BackgroundTasks, HTTPException
import logging
from agents.coordinator import orchestrate_booking
from models.schemas import BookingCreate

router = APIRouter()
logger = logging.getLogger(__name__)


@router.post("/whatsapp")
async def twilio_whatsapp_webhook(request: Request, background_tasks: BackgroundTasks):
    """
    Webhook for Twilio WhatsApp integration.
    Receives incoming WhatsApp messages and triggers the booking pipeline.
    """
    try:
        form_data = await request.form()
        from_number = form_data.get("From", "")
        body = form_data.get("Body", "")

        logger.info(f"Received WhatsApp message from {from_number}: {body}")

        if not body:
            return {"status": "ignored", "reason": "empty body"}

        # Run pipeline in background so Twilio gets a quick 200 OK response
        background_tasks.add_task(
            process_whatsapp_booking, body, from_number
        )

        return {"status": "received"}
    except Exception as e:
        logger.error(f"Error processing WhatsApp webhook: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")


async def process_whatsapp_booking(user_input: str, from_number: str):
    """Background task to run the AI pipeline and send WhatsApp reply."""
    from services.twilio_service import send_whatsapp

    try:
        # Acknowledge receipt
        await send_whatsapp(
            to=from_number,
            message="Khidmat AI: I'm processing your request to find the best provider..."
        )

        # Run the full agent pipeline
        result = await orchestrate_booking(
            user_input=user_input,
            user_lat=24.8607,
            user_lng=67.0011,
            input_type="whatsapp",
        )

        if result.get("success"):
            booking = result.get("booking", {})
            top = result.get("top_providers", [{}])[0] if result.get("top_providers") else {}
            reply = (
                f"Booking Confirmed!\n\n"
                f"Service: {result.get('intent', {}).get('service_type', 'N/A')}\n"
                f"Provider: {top.get('name', 'N/A')} ({top.get('rating', 'N/A')} stars)\n"
                f"Rate: {result.get('final_price', 'N/A')} PKR\n"
                f"Blockchain TX: {booking.get('blockchain_tx_hash', 'pending')}\n\n"
                f"The provider has been dispatched."
            )
        else:
            reply = f"Sorry, I couldn't process your booking right now. Reason: {result.get('error', 'Unknown')}"

        await send_whatsapp(to=from_number, message=reply)
    except Exception as e:
        logger.error(f"Error in WhatsApp background processing: {str(e)}")
        await send_whatsapp(
            to=from_number,
            message="Oops! Something went wrong while orchestrating your request."
        )


@router.post("/telegram")
async def telegram_webhook(request: Request, background_tasks: BackgroundTasks):
    """
    Webhook for Telegram Bot API.
    """
    try:
        update = await request.json()

        if "message" not in update or "text" not in update["message"]:
            return {"status": "ignored"}

        chat_id = update["message"]["chat"]["id"]
        text = update["message"]["text"]

        logger.info(f"Received Telegram message from {chat_id}: {text}")

        # Run the pipeline (in this case we just fire-and-forget)
        background_tasks.add_task(
            orchestrate_booking,
            user_input=text,
            user_lat=24.8607,
            user_lng=67.0011,
            input_type="telegram",
        )

        return {"ok": True}
    except Exception as e:
        logger.error(f"Error processing Telegram webhook: {str(e)}")
        return {"ok": False}
