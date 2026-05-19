"""
Khidmat AI — Coordinator Agent
Orchestrates the full 7-agent pipeline: Intent → Discovery → Matching →
Negotiation → Booking → FollowUp → DemandPrediction.
This is the ROOT orchestrator — the single entry point for all service requests.
"""
import time
import uuid
from agents.intent_agent import run_intent_agent
from agents.discovery_agent import run_discovery_agent
from agents.matching_agent import run_matching_agent
from services.firebase_service import get_traces_for_session


async def orchestrate_booking(
    user_input: str,
    user_lat: float = 24.8607,
    user_lng: float = 67.0099,
    input_type: str = "text",
    womens_safety_mode: bool = False,
    citizen_id: str = "citizen_demo",
    image_base64: str = None,
) -> dict:
    """
    Run the complete 7-agent pipeline for a service booking request.
    
    Pipeline Phase 1: Search & Match
    1. IntentAgent → Extract service type, location, time
    2. DiscoveryAgent → Find nearby providers
    3. MatchingAgent → Rank providers with 5-factor scoring
    
    Returns the top providers for the citizen to select from.
    """
    start_time = time.time()
    session_id = f"session_{uuid.uuid4().hex[:12]}"
    all_traces = []
    pipeline_status = "running"

    try:
        # ====================================
        # STEP 1: Intent Extraction
        # ====================================
        intent_result = await run_intent_agent(
            user_input=user_input, 
            session_id=session_id, 
            input_type=input_type,
            image_base64=image_base64
        )
        all_traces.append(intent_result.get("trace", {}))

        if not intent_result.get("success"):
            return _pipeline_error(
                "IntentAgent failed", intent_result, all_traces, session_id, start_time
            )

        intent = intent_result["intent"]

        # ====================================
        # STEP 2: Provider Discovery
        # ====================================
        discovery_result = await run_discovery_agent(
            intent=intent,
            user_lat=user_lat,
            user_lng=user_lng,
            session_id=session_id,
            womens_safety_mode=womens_safety_mode,
        )
        all_traces.append(discovery_result.get("trace", {}))

        if not discovery_result.get("success"):
            return _pipeline_error(
                "DiscoveryAgent failed", discovery_result, all_traces, session_id, start_time
            )

        candidates = discovery_result.get("candidates", [])
        if not candidates:
            return _pipeline_error(
                "Service unavailable. We are sorry but no provider is giving service in this area",
                discovery_result, all_traces, session_id, start_time
            )


        # ====================================
        # STEP 3: Matching & Ranking
        # ====================================
        matching_result = await run_matching_agent(
            candidates=candidates,
            intent=intent,
            session_id=session_id,
        )
        all_traces.append(matching_result.get("trace", {}))

        if not matching_result.get("success"):
            return _pipeline_error(
                "MatchingAgent failed", matching_result, all_traces, session_id, start_time
            )

        scored_providers = matching_result.get("scored_providers", [])
        fair_price = matching_result.get("fair_price", {})
        counterfactual = matching_result.get("counterfactual", "")
        top_provider = scored_providers[0] if scored_providers else {}

        # ====================================
        # PIPELINE PAUSE: Return to User
        # ====================================
        total_duration_ms = int((time.time() - start_time) * 1000)

        # Helper to get the effective display rate for a provider based on pricing_type
        def _get_effective_rate(p: dict) -> int:
            pt = p.get("pricing_type", "hourly")
            if pt == "per_job":
                return int(p.get("per_job_rate") or p.get("rate") or p.get("hourly_rate") or 0)
            elif pt == "fixed":
                return int(p.get("fixed_rate") or p.get("rate") or p.get("hourly_rate") or 0)
            else:
                return int(p.get("hourly_rate") or p.get("rate") or 0)

        return {
            "success": True,
            "session_id": session_id,
            "top_providers": [
                {
                    "id": p.get("id", ""),
                    "name": p.get("name_en", ""),
                    "rating": p.get("rating", 0),
                    "distance_km": p.get("distance_km", 0),
                    "eta_minutes": p.get("eta_minutes", 0),
                    "hourly_rate": int(p.get("hourly_rate") or 0),
                    "fixed_rate": int(p.get("fixed_rate") or 0),
                    "per_job_rate": int(p.get("per_job_rate") or 0),
                    "rate": _get_effective_rate(p),
                    "pricing_type": p.get("pricing_type") or "hourly",
                    "match_score": p.get("match_score", 0),
                    "trust_badge": p.get("trust_badge", ""),
                    "area_name": p.get("area_name", ""),
                }
                for p in scored_providers[:5]
            ],
            "intent": intent,
            "fair_price": fair_price,
            "counterfactual": counterfactual,
            "weather_warning": discovery_result.get("weather_warning"),
            "agent_traces": all_traces,
            "total_duration_ms": total_duration_ms,
            "pipeline_status": "awaiting_user_selection",
        }

    except Exception as e:
        total_duration_ms = int((time.time() - start_time) * 1000)
        return {
            "success": False,
            "session_id": session_id,
            "error": str(e),
            "agent_traces": all_traces,
            "total_duration_ms": total_duration_ms,
            "pipeline_status": "failed",
        }


def _pipeline_error(
    message: str, result: dict, traces: list, session_id: str, start_time: float
) -> dict:
    """Build error response for pipeline failure."""
    return {
        "success": False,
        "session_id": session_id,
        "error": message,
        "details": result.get("error", ""),
        "agent_traces": traces,
        "total_duration_ms": int((time.time() - start_time) * 1000),
        "pipeline_status": "failed",
    }
