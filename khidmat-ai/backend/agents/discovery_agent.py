"""
KaamSaaz — Agent 2: Discovery Agent
Finds nearby available providers using location, service type, and filters.
Uses Google Maps for distance calculation, weather for outdoor risk.
"""
import time
import uuid
from services.firebase_service import get_providers_by_service, save_agent_trace
from services.maps_service import haversine_km, estimate_eta_minutes, geocode_address
from services.weather_service import get_weather_forecast, check_outdoor_risk

AGENT_NAME = "DiscoveryAgent"


async def run_discovery_agent(
    intent: dict,
    user_lat: float,
    user_lng: float,
    session_id: str,
    womens_safety_mode: bool = False,
) -> dict:
    """
    Discover nearby providers matching the service request.
    Filters by service type, availability, distance, and safety mode.
    """
    start_time = time.time()
    trace_id = str(uuid.uuid4())[:12]

    try:
        service_type = intent.get("service_type", "electrician")
        location = intent.get("location", "")
        gender_filter = "female" if womens_safety_mode else "male"

        import asyncio
        
        # Prepare concurrent tasks
        providers_task = get_providers_by_service(
            service_type=service_type,
            is_available=True,
            gender=gender_filter,
            limit_count=50,
        )

        geo = None
        if location:
            # Run geocode and providers fetch concurrently
            geo_task = geocode_address(location)
            providers, geo = await asyncio.gather(providers_task, geo_task)
        else:
            providers = await providers_task

        # Extract coordinates
        if geo:
            # Only update coordinates if the ones passed are default Karachi coordinates.
            # If the user selected a high-precision coordinate (different from Karachi default),
            # do not overwrite it with the text-geocoded coordinates!
            is_default_coords = (abs(user_lat - 24.8607) < 0.001) and (abs(user_lng - 67.0099) < 0.001)
            if is_default_coords:
                user_lat = geo["lat"]
                user_lng = geo["lng"]

        # Get weather for outdoor risk assessment
        weather = await get_weather_forecast(user_lat, user_lng)
        weather_warning = check_outdoor_risk(weather, service_type)

        print(f"[DiscoveryAgent] service_type='{service_type}' -> {len(providers)} providers from DB")

        # Calculate distance and ETA for each provider
        candidates = []
        seen_names = set()
        seen_phones = set()
        seen_ids = set()

        for provider in providers:
            p_id = provider.get("id") or ""
            name = provider.get("name_en", "").lower().strip()
            phone = provider.get("phone", "").strip()

            # Skip duplicate profiles by unique ID only (allows testing multiple accounts with same name/phone)
            if p_id in seen_ids:
                print(f"[DiscoveryAgent] Skipping duplicate ID of '{provider.get('name_en')}'")
                continue

            p_lat = provider.get("lat") or 0
            p_lng = provider.get("lng") or 0
            distance = haversine_km(user_lat, user_lng, p_lat, p_lng)
            # Use a very large coverage radius so no one is excluded during discovery
            # (matching agent will rank by distance anyway)
            coverage = float(provider.get("coverage_radius_km") or 500)

            print(f"[DiscoveryAgent] Provider '{provider.get('name_en')}': dist={distance:.1f}km coverage={coverage}km")

            # Strictly filter providers outside the 15.0 km service radius
            if distance > 15.0:
                print(f"[DiscoveryAgent] Skipping {provider.get('name_en')} — outside 15km radius ({distance:.1f}km)")
                continue


            eta = estimate_eta_minutes(distance)
            seen_ids.add(p_id)
            seen_names.add(name)
            if phone:
                seen_phones.add(phone)
            candidates.append({
                **provider,
                "distance_km": distance,
                "eta_minutes": eta,
            })

        # Sort by distance
        candidates.sort(key=lambda x: x["distance_km"])
        candidates = candidates[:20]
        print(f"[DiscoveryAgent] Final candidates: {len(candidates)}")

        duration_ms = int((time.time() - start_time) * 1000)

        reasoning = (
            f"Found {len(candidates)} available {service_type} providers "
            f"near ({user_lat:.4f}, {user_lng:.4f}). "
            f"Searched {len(providers)} total, filtered by coverage radius. "
        )
        if womens_safety_mode:
            reasoning += "Women's Safety Mode active — filtered to female providers. "
        if weather_warning:
            reasoning += f"Weather alert: {weather_warning}"

        trace = {
            "id": trace_id,
            "session_id": session_id,
            "agent_name": AGENT_NAME,
            "step_number": 2,
            "input_data": {
                "service_type": service_type,
                "location": location,
                "user_coords": {"lat": user_lat, "lng": user_lng},
                "womens_safety_mode": womens_safety_mode,
            },
            "output_data": {
                "candidates_found": len(candidates),
                "total_searched": len(providers),
                "weather_warning": weather_warning,
            },
            "tool_calls": [
                {"tool": "firestore_query", "status": "success"},
                {"tool": "geocode_address", "status": "success" if location else "skipped"},
                {"tool": "weather_forecast", "status": "success"},
                {"tool": "haversine_distance", "status": "success", "count": len(providers)},
            ],
            "reasoning_text": reasoning,
            "duration_ms": duration_ms,
            "status": "success",
        }
        await save_agent_trace(trace)

        return {
            "success": True,
            "candidates": candidates,
            "weather": weather,
            "weather_warning": weather_warning,
            "user_coords": {"lat": user_lat, "lng": user_lng},
            "trace": trace,
        }

    except Exception as e:
        duration_ms = int((time.time() - start_time) * 1000)
        trace = {
            "id": trace_id,
            "session_id": session_id,
            "agent_name": AGENT_NAME,
            "step_number": 2,
            "input_data": {"service_type": intent.get("service_type")},
            "output_data": {"error": str(e)},
            "reasoning_text": f"Discovery failed: {e}",
            "duration_ms": duration_ms,
            "status": "error",
        }
        await save_agent_trace(trace)
        return {"success": False, "error": str(e), "trace": trace}
