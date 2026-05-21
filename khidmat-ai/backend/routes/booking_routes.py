"""
KaamSaaz — Booking Routes
Core API endpoints for the booking pipeline and booking management.
"""
from fastapi import APIRouter, HTTPException
from models.schemas import BookingCreate, AgentPipelineResponse
from pydantic import BaseModel
from typing import Dict, Any, Optional

from agents.coordinator import orchestrate_booking
from agents.negotiation_agent import run_negotiation_agent
from agents.booking_agent import run_booking_agent
from agents.followup_agent import run_followup_agent
from agents.demand_agent import run_demand_agent
from services.firebase_service import (
    get_document, query_collection, get_traces_for_session
)
from services.maps_service import haversine_km

router = APIRouter()

# Global provider caches to eliminate N+1 query overhead in booking lists
_provider_name_cache: Dict[str, str] = {}
_provider_rating_cache: Dict[str, float] = {}
_provider_jobs_cache: Dict[str, int] = {}

class ConfirmBookingRequest(BaseModel):
    session_id: str
    # Accept both field names for Flutter / web compatibility
    provider_id: Optional[str] = None
    selected_provider_id: Optional[str] = None
    intent: Optional[Dict[str, Any]] = None
    fair_price: Optional[Dict[str, Any]] = None
    counterfactual: str = ""
    match_score: float = 0.0
    womens_safety_mode: bool = False
    citizen_id: str = "citizen_demo"
    user_name: str = "Customer"
    user_phone: str = "+92300000000"
    user_lat: Optional[float] = None
    user_lng: Optional[float] = None

    def get_provider_id(self) -> str:
        return self.provider_id or self.selected_provider_id or ""


@router.post("/book", response_model=None)
async def create_booking(request: BookingCreate):
    """
    Execute the full 7-agent booking pipeline.
    
    Input: Natural language service request (Roman Urdu / Urdu / English)
    Output: Confirmed booking with agent traces, payment, and blockchain record.
    
    This is the PRIMARY endpoint — demonstrates the complete agentic workflow.
    """
    result = await orchestrate_booking(
        user_input=request.user_input,
        user_lat=request.lat,
        user_lng=request.lng,
        input_type=request.input_type,
        womens_safety_mode=request.womens_safety_mode,
        image_base64=request.image_base64,
    )

    if not result.get("success"):
        raise HTTPException(
            status_code=422,
            detail={
                "error": result.get("error", "Pipeline failed"),
                "session_id": result.get("session_id", ""),
                "agent_traces": result.get("agent_traces", []),
            },
        )

    return result


@router.post("/book/confirm")
async def confirm_booking(req: ConfirmBookingRequest):
    """
    Phase 2: After user selects a provider, complete Negotiation, Booking, and FollowUp.
    """
    pid = req.get_provider_id()
    if not pid:
        raise HTTPException(status_code=400, detail="provider_id or selected_provider_id is required")
    provider = await get_document("providers", pid)
    if not provider:
        raise HTTPException(status_code=404, detail=f"Provider '{pid}' not found")

    # Build sensible defaults for intent and fair_price if not supplied
    intent = req.intent or {
        "service_type": provider.get("service_type_id", "general"),
        "location": provider.get("area_name", "Karachi"),
        "urgency": "normal",
        "date": "today",
        "time": "now",
    }
    def get_active_rate(c):
        pt = c.get("pricing_type", "hourly")
        if pt == "fixed":
            return c.get("fixed_rate") or c.get("rate") or c.get("hourly_rate") or 1500
        elif pt == "per_job":
            return c.get("per_job_rate") or c.get("rate") or c.get("hourly_rate") or 1500
        else:
            return c.get("hourly_rate") or c.get("rate") or 1500

    active_rate = get_active_rate(provider)
    fair_price = req.fair_price or {
        "fair_price": active_rate,
        "min_price": active_rate,
        "max_price": active_rate * 2,
        "currency": "PKR",
    }

    all_traces = []

    # 4. Negotiation
    negotiation_result = await run_negotiation_agent(
        provider=provider,
        intent=intent,
        fair_price=fair_price,
        session_id=req.session_id,
    )
    all_traces.append(negotiation_result.get("trace", {}))
    final_price = negotiation_result.get("final_price", active_rate)
    negotiation_log = negotiation_result.get("negotiation_log", [])

    # 5. Booking
    booking_result = await run_booking_agent(
        provider=provider,
        intent=intent,
        final_price=final_price,
        negotiation_log=negotiation_log,
        fair_price=fair_price,
        counterfactual=req.counterfactual,
        match_score=req.match_score,
        session_id=req.session_id,
        citizen_id=req.citizen_id,
        user_name=req.user_name,
        user_phone=req.user_phone,
        womens_safety_mode=req.womens_safety_mode,
        user_lat=req.user_lat,
        user_lng=req.user_lng,
    )
    all_traces.append(booking_result.get("trace", {}))

    if not booking_result.get("success"):
        raise HTTPException(status_code=400, detail="Booking Agent failed")

    # 6. Follow-up
    followup_result = await run_followup_agent(
        booking=booking_result.get("booking", {}),
        provider=provider,
        session_id=req.session_id,
        action="schedule_reminders",
    )
    all_traces.append(followup_result.get("trace", {}))

    booking_obj = booking_result.get("booking", {})
    booking_obj["provider_name"] = provider.get("name_en") or provider.get("name") or "Professional"
    booking_obj["provider_rating"] = provider.get("rating", 4.8)
    booking_obj["provider_jobs_count"] = provider.get("jobs_completed", 0)

    return {
        "success": True,
        "session_id": req.session_id,
        "booking": booking_obj,
        "booking_id": booking_result.get("booking_id", ""),
        "final_price": final_price,
        "actions_taken": booking_result.get("actions_taken", []),
        "followup_actions": followup_result.get("actions_taken", []),
        "payment": booking_result.get("payment", {}),
        "blockchain": booking_result.get("blockchain", {}),
        "agent_traces": all_traces,
        "pipeline_status": "completed"
    }


@router.get("/bookings/{booking_id}")
async def get_booking(booking_id: str):
    """Get booking details by ID."""
    booking = await get_document("bookings", booking_id)
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
    
    # Enrich booking with provider rating and jobs completed dynamically
    pid = booking.get("provider_id")
    if pid:
        provider = await get_document("providers", pid)
        if provider:
            booking["provider_rating"] = provider.get("rating", 4.8)
            booking["provider_jobs_count"] = provider.get("jobs_completed", 0)
            booking["provider_name"] = provider.get("name_en") or provider.get("name") or booking.get("provider_name", "Professional")
            
    return booking


@router.get("/bookings")
async def list_bookings(
    status: str = None,
    provider_id: str = None,
    citizen_id: str = None,
    limit: int = 20,
):
    """List bookings with optional status, provider_id, and citizen_id filter."""
    if status == "pending" and provider_id:
        # Get provider profile to find their service_type_id and coordinates
        provider = await get_document("providers", provider_id)
        if provider:
            p_service = provider.get("service_type_id")
            p_lat = provider.get("lat")
            p_lng = provider.get("lng")
            
            # Fetch ALL pending bookings
            all_pending = await query_collection("bookings", filters=[("status", "==", "pending")], limit=100)
            
            bookings = []
            # Sort bookings: recommended/assigned first, then same service type within 15km, then other service types within 15km
            for b in all_pending:
                b_pid = b.get("provider_id")
                # 1. Directly assigned/recommended to this provider
                if b_pid == provider_id:
                    b["is_recommended"] = True
                    b["distance_to_provider_km"] = 0.0
                    bookings.append(b)
                # 2. Others within 15km radius
                else:
                    b_lat = b.get("service_lat") or b.get("lat")
                    b_lng = b.get("service_lng") or b.get("lng")
                    if b_lat is not None and b_lng is not None and p_lat is not None and p_lng is not None:
                        dist = haversine_km(float(p_lat), float(p_lng), float(b_lat), float(b_lng))
                        if dist <= 15.0:
                            b["is_recommended"] = False
                            b["distance_to_provider_km"] = dist
                            bookings.append(b)
                    else:
                        # Fallback if coordinates are missing: allow only if it's the same service type
                        if b.get("service_type_id") == p_service:
                            b["is_recommended"] = False
                            b["distance_to_provider_km"] = 0.0
                            bookings.append(b)
            # Sort: 1. is_recommended (True first) 2. same service type (True first) 3. distance ascending
            bookings.sort(key=lambda x: (
                not x.get("is_recommended", False),
                x.get("service_type_id") != p_service,
                x.get("distance_to_provider_km", 999.0)
            ))
        else:
            filters = [("status", "==", "pending"), ("provider_id", "eq", provider_id)]
            bookings = await query_collection("bookings", filters=filters, limit=limit)
    else:
        filters = []
        if status:
            filters.append(("status", "==", status))
        if provider_id:
            filters.append(("provider_id", "eq", provider_id))
        if citizen_id:
            filters.append(("citizen_id", "eq", citizen_id))
        bookings = await query_collection("bookings", filters=filters, limit=limit)

    
    # Enrich with provider details (uses global caches to avoid N+1 sequential HTTP requests)
    missing_ids = []
    for booking in bookings:
        pid = booking.get("provider_id")
        if pid:
            if pid in _provider_name_cache:
                booking["provider_name"] = _provider_name_cache[pid]
                booking["provider_rating"] = _provider_rating_cache.get(pid, 4.8)
                booking["provider_jobs_count"] = _provider_jobs_cache.get(pid, 0)
            else:
                missing_ids.append(pid)
                
    if missing_ids:
        # Fetch all providers to populate the cache in a single query
        all_providers = await query_collection("providers")
        for p in all_providers:
            p_id = p.get("id")
            if p_id:
                name = p.get("name_en") or p.get("name") or p_id
                _provider_name_cache[p_id] = name
                _provider_rating_cache[p_id] = p.get("rating", 4.8)
                _provider_jobs_cache[p_id] = p.get("jobs_completed", 0)
        
        # Assign resolved details from cache
        for booking in bookings:
            pid = booking.get("provider_id")
            if pid:
                booking["provider_name"] = _provider_name_cache.get(pid, pid)
                booking["provider_rating"] = _provider_rating_cache.get(pid, 4.8)
                booking["provider_jobs_count"] = _provider_jobs_cache.get(pid, 0)
    
    return {"bookings": bookings, "total": len(bookings)}


@router.get("/traces/{session_id}")
async def get_agent_traces(session_id: str):
    """Get all agent traces for a booking session."""
    traces = await get_traces_for_session(session_id)
    return {
        "session_id": session_id,
        "traces": traces,
        "total_agents": len(traces),
    }


@router.post("/bookings/{booking_id}/followup")
async def trigger_followup(booking_id: str, action: str = "request_review"):
    """Trigger a follow-up action for a booking."""
    booking = await get_document("bookings", booking_id)
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")

    # Get provider info
    provider = await get_document("providers", booking.get("provider_id", ""))

    result = await run_followup_agent(
        booking=booking,
        provider=provider or {},
        session_id=booking.get("agent_reasoning", {}).get("session_id", "manual"),
        action=action,
    )
    return result


@router.get("/demand")
async def get_demand_predictions():
    """Get demand predictions from the DemandPredictionAgent."""
    result = await run_demand_agent(session_id="demand_check")
    return result

@router.post("/bookings/{booking_id}/accept")
async def accept_booking(booking_id: str):
    """
    Real-time Provider Action: Accept a pending booking.
    This triggers the final confirmation, blockchain recording, and escrow.
    """
    from services.firebase_service import update_document
    from services.blockchain_service import record_on_blockchain
    from services.payment_service import simulate_jazzcash_payment, create_escrow
    
    booking = await get_document("bookings", booking_id)
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
        
    if booking.get("status") != "pending":
        raise HTTPException(status_code=400, detail="Booking is not pending")
        
    # 1. Simulate Payment & Escrow
    payment = await simulate_jazzcash_payment(
        amount=booking.get("quoted_price", 0),
        booking_id=booking_id,
        phone="+923001234567"
    )
    escrow = await create_escrow(booking_id, booking.get("quoted_price", 0))
    
    # 2. Record on Blockchain now that it's mutually agreed
    blockchain = await record_on_blockchain(booking)
    
    # 3. Update database
    updates = {
        "status": "confirmed",
        "blockchain_tx_hash": blockchain.get("tx_hash", ""),
        "blockchain_confirmed": blockchain.get("success", False),
        "jazzcash_transaction_id": payment.get("transaction_id", ""),
        "escrow_active": True,
        "escrow_id": escrow.get("escrow_id", "")
    }
    
    await update_document("bookings", booking_id, updates)
    
    return {
        "success": True,
        "message": "Booking confirmed successfully",
        "blockchain": blockchain,
        "escrow_id": escrow.get("escrow_id")
    }


@router.post("/bookings/{booking_id}/cancel")
async def cancel_booking(booking_id: str):
    """
    Real-time Action: Cancel a booking.
    This works for both Customer and Provider. Marks booking status as 'cancelled'.
    """
    from services.firebase_service import update_document, get_document
    from datetime import datetime
    
    booking = await get_document("bookings", booking_id)
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
        
    current_status = booking.get("status")
    if current_status not in ["pending", "confirmed"]:
        raise HTTPException(status_code=400, detail=f"Booking in status '{current_status}' cannot be cancelled")
        
    updates = {
        "status": "cancelled",
        "updated_at": datetime.utcnow().isoformat()
    }
    
    success = await update_document("bookings", booking_id, updates)
    if not success:
        raise HTTPException(status_code=500, detail="Failed to update booking status in database")
        
    return {
        "success": True,
        "message": "Booking cancelled successfully"
    }


@router.post("/bookings/{booking_id}/complete")
async def complete_booking(booking_id: str):
    """
    Real-time Provider Action: Mark a booking as completed.
    This releases the escrow, records the completion on the blockchain, and triggers follow-up/review.
    """
    from services.firebase_service import update_document, get_document
    from services.blockchain_service import record_on_blockchain
    from services.payment_service import release_escrow
    from datetime import datetime
    
    booking = await get_document("bookings", booking_id)
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
        
    current_status = booking.get("status")
    if current_status != "confirmed" and current_status != "completed":
        raise HTTPException(status_code=400, detail=f"Only confirmed bookings can be marked as completed (current status: {current_status})")
        
    if current_status == "completed":
        return {
            "success": True,
            "message": "Booking already completed",
            "blockchain_confirmed": True
        }
        
    # 1. Release Escrow
    escrow_id = booking.get("escrow_id") or f"ESC-{booking_id[:8].upper()}"
    release_res = await release_escrow(escrow_id)
    
    # 2. Record completion on Blockchain
    # Update the status to completed first so record_on_blockchain logs the correct final state
    booking["status"] = "completed"
    blockchain = await record_on_blockchain(booking)
    
    # 3. Update database
    updates = {
        "status": "completed",
        "escrow_active": False,
        "payment_released": True,
        "completed_at": datetime.utcnow().isoformat(),
        "completion_blockchain_tx_hash": blockchain.get("tx_hash", ""),
        "updated_at": datetime.utcnow().isoformat()
    }
    
    await update_document("bookings", booking_id, updates)
    
    # Update provider stats for admin and provider dashboards
    provider_id = booking.get("provider_id", "")
    provider = None
    if provider_id:
        provider = await get_document("providers", provider_id)
        if not provider:
            # Try fallback query lookup in case the doc_id isn't matches provider_id exactly
            from services.firebase_service import query_collection
            results = await query_collection("providers", filters=[("id", "eq", provider_id)])
            if results:
                provider = results[0]
        
        if provider:
            doc_id = provider.get("id") or provider_id
            completed_jobs = int(provider.get("jobs_completed", 0)) + 1
            await update_document("providers", doc_id, {
                "jobs_completed": completed_jobs,
                "is_available": True
            })
            
            # Clear admin dashboard stats cache immediately for real-time updates
            try:
                from routes.admin_routes import clear_admin_stats_cache
                clear_admin_stats_cache()
            except Exception as e:
                print(f"Error clearing stats cache: {e}")
    
    # 4. Trigger Follow-Up Agent to request user review
    # Get provider info for follow-up agent
    if not provider and provider_id:
        provider = await get_document("providers", provider_id)
    try:
        await run_followup_agent(
            booking={**booking, **updates},
            provider=provider or {},
            session_id=booking.get("agent_reasoning", {}).get("session_id", "manual"),
            action="request_review",
        )
    except Exception as e:
        print(f"Non-blocking error triggering follow-up agent: {e}")
    
    return {
        "success": True,
        "message": "Booking marked as completed successfully and payment released",
        "blockchain": blockchain,
        "escrow_release": release_res
    }


