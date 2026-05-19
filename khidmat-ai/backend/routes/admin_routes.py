"""
Khidmat AI — Admin Routes
Dashboard analytics, booking stats, and system management with optimized in-memory caching.
"""
import time
import json
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from services.firebase_service import query_collection, get_all_documents, get_document, create_document
from services.gemini_service import generate_text
from agents.demand_agent import run_demand_agent

router = APIRouter()

class AdminLoginRequest(BaseModel):
    username: str
    password: str

@router.post("/admin/login")
async def admin_login(req: AdminLoginRequest):
    """
    Authenticate admin credentials against Firebase / Supabase.
    Stores and reads from the database.
    """
    # 1. Ensure the admin credentials exist in Supabase/Firebase collection 'admins'
    admin_doc = await get_document("admins", req.username)
    if not admin_doc:
        # Create it if it doesn't exist to store it securely in the backend DB
        await create_document("admins", {
            "username": "admin123",
            "password": "admin@123",
            "role": "superadmin"
        }, doc_id="admin123")
        admin_doc = await get_document("admins", req.username)
        
    # 2. Verify the username and password
    if admin_doc and admin_doc.get("password") == req.password:
        return {"success": True, "token": "admin_session_token_xyz_123"}
        
    raise HTTPException(status_code=401, detail="Invalid admin credentials")

class AdminCopilotRequest(BaseModel):
    message: str
    history: list[dict] = []

@router.post("/admin/copilot")
async def admin_copilot(req: AdminCopilotRequest):
    """
    Khidmat Copilot endpoint. Real-time data from the database is fed
    into Gemini to guarantee accurate responses without hallucinations.
    """
    try:
        # Fetch latest dynamic marketplace data
        bookings = await get_all_documents("bookings")
        providers = await get_all_documents("providers")
        traces = await query_collection("agentTraces", limit=10, order_by="-created_at")

        # Aggregate metrics
        confirmed_bookings = [b for b in bookings if b.get("status") in ["confirmed", "completed", "pending"]]
        total_rev = sum(b.get("final_price") or b.get("quoted_price") or b.get("price") or 0 for b in confirmed_bookings)

        # Format context
        providers_ctx = []
        for idx, p in enumerate(providers):
            p_name = p.get("name_en") or p.get("name") or "Unnamed Provider"
            p_jobs = p.get("jobs_completed") if p.get("jobs_completed") is not None else 0
            p_rating = p.get("rating") if p.get("rating") is not None else 5.0
            p_specialty = p.get("service_type_id") or "General"
            
            # Count bookings for this provider
            prov_bookings = [b for b in bookings if b.get("provider_id") == p.get("id")]
            completed_bookings = [b for b in prov_bookings if b.get("status") == "completed"]
            
            # Use jobs_completed directly from provider registry (which is updated upon job completion)
            total_jobs = p_jobs
            
            # Calculate actual income from completed bookings
            p_income = sum(b.get("final_price") or b.get("quoted_price") or b.get("price") or 0 for b in completed_bookings)
            if p_income == 0 and total_jobs > 0:
                p_rate = p.get("rate") or p.get("hourly_rate") or p.get("fixed_rate") or 800
                p_income = total_jobs * p_rate

            providers_ctx.append({
                "rank": idx + 1,
                "id": p.get("id"),
                "name": p_name,
                "specialty": p_specialty,
                "rating": p_rating,
                "gender": p.get("gender") or "male",
                "jobs_completed": total_jobs,
                "total_income_pkr": p_income,
                "is_available": p.get("is_available", False),
                "location": p.get("area_name") or f"{p.get('latitude')}, {p.get('longitude')}"
            })

        bookings_ctx = []
        for b in bookings:
            # Resolve customer name
            cust_name = b.get("user_name") or b.get("citizen_id") or "Customer"
            # Resolve provider name
            prov_id = b.get("provider_id")
            prov_obj = next((p for p in providers if p.get("id") == prov_id), None)
            p_name = prov_obj.get("name_en") or prov_obj.get("name") if prov_obj else "Unassigned"

            bookings_ctx.append({
                "id": b.get("id"),
                "customer": cust_name,
                "provider": p_name,
                "status": b.get("status"),
                "price_pkr": b.get("final_price") or b.get("quoted_price") or b.get("price") or 0,
                "service": b.get("service_type_id"),
                "date": b.get("scheduled_date") or b.get("resolved_date"),
                "time": b.get("scheduled_time") or b.get("resolved_time")
            })

        traces_ctx = [
            {
                "agent": t.get("agent_name", "UnknownAgent").replace("Agent", ""),
                "action": t.get("reasoning_text") or "Completed execution",
                "timestamp": t.get("created_at")
            }
            for t in traces
        ]

        # Build comprehensive system prompt with marketplace guardrails
        system_instruction = f"""You are the Khidmat Copilot, a highly sophisticated AI marketplace orchestrator and dashboard assistant for the Khidmat AI marketplace in Pakistan.

Your absolute priority is to answer the administrator's queries precisely and accurately using ONLY the live, real-time marketplace data provided below.

=== LIVE DASHBOARD DATA CONTEXT ===
1. Aggregate Statistics:
   - Total Bookings: {len(bookings)}
   - Active Providers: {len(providers)}
   - Gross Merchandise Value (GMV): PKR {total_rev:,}
   - Successful/Confirmed Bookings Count: {len(confirmed_bookings)}

2. Active Providers Registry (Earnings & Performance):
{json.dumps(providers_ctx, indent=2)}

3. Bookings Ledger:
{json.dumps(bookings_ctx, indent=2)}

4. Recent Agent Reasoning Traces:
{json.dumps(traces_ctx, indent=2)}

=== STRICT ADMINISTRATIVE GUARDRAILS ===
1. Respond using ONLY the facts, numbers, ratings, earnings, and locations present in the provided context.
2. If new data is added or modified in the provided context, recalculate aggregates immediately.
3. If asked about a provider, booking, or statistic that is NOT in the database, clearly state: "According to the real-time dashboard data, no such record currently exists."
4. Do NOT make up, guess, or extrapolate any names, transactions, ratings, or locations. Keep your answers factual and precise.
5. DYNAMIC LANGUAGE ADAPTATION: Detect the language of the administrator's latest query dynamically. If the administrator uses Roman Urdu (Urdu written in English letters, e.g., "Babar Azam ne kitne kamaye?", "sab se zyada jobs kis ki hain?", "total bookings kitni hain?"), respond entirely in professional, fluent, conversational Roman Urdu. If the administrator uses English, respond entirely in English. If they change the language mid-conversation, match their language switch immediately. Do NOT return JSON messages.
6. Provide helpful calculations or summaries if requested (e.g. average booking price, top-performing specialty, etc.).
"""

        # Format prompt with chat history to support conversation continuity
        prompt_parts = []
        for h in req.history[-6:]:  # Keep last 3 exchanges (6 messages)
            role = "Administrator" if h.get("role") == "user" else "Copilot"
            prompt_parts.append(f"{role}: {h.get('text')}")
        prompt_parts.append(f"Administrator: {req.message}")
        prompt = "\n".join(prompt_parts)

        # Call Gemini SDK
        response_text = await generate_text(
            prompt=prompt,
            system_instruction=system_instruction,
            temperature=0.2
        )
        
        response_text = response_text.strip()
        # Defensive JSON extraction if returned inside a JSON string
        if response_text.startswith("{") and response_text.endswith("}"):
            try:
                parsed_json = json.loads(response_text)
                if isinstance(parsed_json, dict):
                    response_text = parsed_json.get("response") or parsed_json.get("text") or response_text
            except Exception:
                pass

        # Remove markdown JSON blocks if present
        if "```json" in response_text:
            response_text = response_text.split("```json")[-1].split("```")[0].strip()
            try:
                parsed_json = json.loads(response_text)
                if isinstance(parsed_json, dict):
                    response_text = parsed_json.get("response") or parsed_json.get("text") or response_text
            except Exception:
                pass

        return {"response": response_text}

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Copilot query failed: {str(e)}")

# Time-based memory caches to make the dashboard respond in milliseconds
_stats_cache = None
_stats_cache_time = 0.0
_stats_cache_duration = 10.0  # Cache dashboard stats for 10 seconds

_perf_cache = None
_perf_cache_time = 0.0
_perf_cache_duration = 20.0  # Cache heavy agent performance traces for 20 seconds

_forecast_cache = None
_forecast_cache_time = 0.0
_forecast_cache_duration = 60.0  # Cache predictive forecasting for 60 seconds


def clear_admin_stats_cache():
    """Clear the admin dashboard stats cache immediately."""
    global _stats_cache
    _stats_cache = None


@router.get("/admin/stats")
async def get_dashboard_stats():
    """Get aggregated stats for admin dashboard with caching."""
    global _stats_cache, _stats_cache_time
    now = time.time()
    
    if _stats_cache is not None and (now - _stats_cache_time) < _stats_cache_duration:
        return _stats_cache
        
    bookings = await get_all_documents("bookings")
    providers = await get_all_documents("providers")

    # Booking stats
    total_bookings = len(bookings)
    confirmed = sum(1 for b in bookings if b.get("status") == "confirmed")
    completed = sum(1 for b in bookings if b.get("status") == "completed")
    cancelled = sum(1 for b in bookings if b.get("status") == "cancelled")

    # Revenue
    total_revenue = sum(b.get("quoted_price", 0) for b in bookings if b.get("status") in ["confirmed", "completed"])

    # Provider stats
    total_providers = len(providers)
    available = sum(1 for p in providers if p.get("is_available", False))
    verified = sum(1 for p in providers if p.get("cnic_verified", False))

    # Service distribution
    service_dist: dict[str, int] = {}
    for b in bookings:
        st = b.get("service_type_id", "unknown")
        service_dist[st] = service_dist.get(st, 0) + 1

    # Area distribution
    area_dist: dict[str, int] = {}
    for b in bookings:
        area = b.get("service_area", "unknown")
        area_dist[area] = area_dist.get(area, 0) + 1

    # Average ratings
    rated = [p for p in providers if p.get("rating", 0) > 0]
    avg_rating = round(sum(p["rating"] for p in rated) / max(len(rated), 1), 2)

    stats = {
        "bookings": {
            "total": total_bookings,
            "confirmed": confirmed,
            "completed": completed,
            "cancelled": cancelled,
        },
        "revenue": {
            "total_pkr": total_revenue,
            "average_pkr": round(total_revenue / max(total_bookings, 1)),
        },
        "providers": {
            "total": total_providers,
            "available": available,
            "verified": verified,
            "average_rating": avg_rating,
        },
        "service_distribution": service_dist,
        "area_distribution": area_dist,
    }
    
    _stats_cache = stats
    _stats_cache_time = now
    return stats


@router.get("/admin/agent-performance")
async def get_agent_performance():
    """Get agent execution performance metrics with caching."""
    global _perf_cache, _perf_cache_time
    now = time.time()
    
    if _perf_cache is not None and (now - _perf_cache_time) < _perf_cache_duration:
        return _perf_cache
        
    traces = await get_all_documents("agentTraces")

    agent_stats: dict[str, dict] = {}
    for trace in traces:
        name = trace.get("agent_name", "unknown")
        if name not in agent_stats:
            agent_stats[name] = {
                "total_runs": 0,
                "success": 0,
                "errors": 0,
                "total_duration_ms": 0,
            }
        agent_stats[name]["total_runs"] += 1
        if trace.get("status") == "success":
            agent_stats[name]["success"] += 1
        elif trace.get("status") == "error":
            agent_stats[name]["errors"] += 1
        agent_stats[name]["total_duration_ms"] += trace.get("duration_ms", 0)

    # Calculate averages
    for name, stats in agent_stats.items():
        runs = stats["total_runs"]
        stats["avg_duration_ms"] = round(stats["total_duration_ms"] / max(runs, 1))
        stats["success_rate"] = round(stats["success"] / max(runs, 1) * 100, 1)

    result = {"agents": agent_stats, "total_traces": len(traces)}
    
    _perf_cache = result
    _perf_cache_time = now
    return result


@router.get("/admin/demand-forecast")
async def get_demand_forecast():
    """Get demand predictions for admin dashboard with caching."""
    global _forecast_cache, _forecast_cache_time
    now = time.time()
    
    if _forecast_cache is not None and (now - _forecast_cache_time) < _forecast_cache_duration:
        return _forecast_cache
        
    result = await run_demand_agent(session_id="admin_forecast")
    
    _forecast_cache = result
    _forecast_cache_time = now
    return result


@router.get("/admin/recent-traces")
async def get_recent_traces(limit: int = 15):
    """Get recent agent execution traces for live tracking on the dashboard."""
    from datetime import datetime
    traces = await query_collection("agentTraces", limit=limit, order_by="-created_at")
    return {
        "traces": [
            {
                "agent": t.get("agent_name", "Unknown").replace("Agent", ""),
                "action": t.get("reasoning_text") or str(t.get("output_data", {}).get("error", "Executed successfully")),
                "timestamp": t.get("created_at") or datetime.utcnow().isoformat()
            }
            for t in traces
        ]
    }


@router.get("/admin/debug/bookings")
async def debug_bookings():
    """Debug: list all bookings with key fields to diagnose ID issues."""
    bookings = await get_all_documents("bookings")
    return {
        "total": len(bookings),
        "bookings": [
            {
                "id": b.get("id"),
                "status": b.get("status"),
                "provider_id": b.get("provider_id"),
                "citizen_id": b.get("citizen_id"),
                "user_name": b.get("user_name"),
                "service_type_id": b.get("service_type_id"),
                "scheduled_date": b.get("scheduled_date"),
            }
            for b in bookings
        ],
    }


@router.get("/admin/debug/providers")
async def debug_providers():
    """Debug: list all providers with key fields."""
    providers = await get_all_documents("providers")
    return {
        "total": len(providers),
        "providers": [
            {
                "id": p.get("id"),
                "name_en": p.get("name_en"),
                "service_type_id": p.get("service_type_id"),
                "is_available": p.get("is_available"),
                "area_name": p.get("area_name"),
            }
            for p in providers
        ],
    }
