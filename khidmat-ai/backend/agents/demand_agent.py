"""
Khidmat AI — Agent 7: Demand Prediction Agent
Predicts service demand surges using weather, historical data, and events.
"""
import time
import uuid
from datetime import datetime
from services.weather_service import get_weather_forecast, get_demand_signals
from services.firebase_service import (
    save_agent_trace, query_collection
)

AGENT_NAME = "DemandPredictionAgent"


async def run_demand_agent(session_id: str) -> dict:
    """
    Analyze demand patterns and predict surges.
    Uses weather data, booking history, and time patterns.
    """
    start_time = time.time()
    trace_id = str(uuid.uuid4())[:12]

    try:
        # 1. Get weather signals
        weather = await get_weather_forecast(days=3)
        weather_signals = get_demand_signals(weather)

        # 2. Analyze booking history patterns
        recent_bookings = await query_collection(
            "bookings", limit=100
        )

        # Count by service type
        service_counts: dict[str, int] = {}
        area_counts: dict[str, int] = {}
        for booking in recent_bookings:
            st = booking.get("service_type_id", "unknown")
            area = booking.get("service_area", "unknown")
            service_counts[st] = service_counts.get(st, 0) + 1
            area_counts[area] = area_counts.get(area, 0) + 1

        # 3. Time-based patterns
        now = datetime.now()
        hour = now.hour
        is_peak = (7 <= hour <= 9) or (17 <= hour <= 20)
        is_friday = now.weekday() == 4  # Friday — prayer times
        is_weekend = now.weekday() >= 5

        time_signals = []
        if is_peak:
            time_signals.append("Peak hours active — expect 30% higher demand")
        if is_friday:
            time_signals.append("Friday — reduced availability 12:00-14:30 (Jummah prayer)")
        if is_weekend:
            time_signals.append("Weekend — beautician and tutor demand typically +25%")

        # 4. Seasonal patterns (Karachi specific)
        month = now.month
        seasonal_signals = []
        if month in [5, 6, 7, 8]:  # Summer
            seasonal_signals.append("Summer season — AC technician demand at peak")
            seasonal_signals.append("Generator repair demand elevated due to load-shedding")
        if month in [7, 8]:  # Monsoon
            seasonal_signals.append("Monsoon season — plumber demand surge expected")
            seasonal_signals.append("Outdoor services (painter, welder) may face delays")
        if month == 12 or month == 1:
            seasonal_signals.append("Winter — heater/geyser repair demand increasing")

        # 5. Build predictions
        predictions = []

        # Top demanded service
        if service_counts:
            top_service = max(service_counts, key=service_counts.get)
            predictions.append({
                "type": "trending_service",
                "service": top_service,
                "count": service_counts[top_service],
                "message": f"{top_service} is the most requested service currently",
            })

        # Weather-driven predictions
        for signal in weather_signals:
            predictions.append({
                "type": "weather_driven",
                "message": signal,
                "confidence": 0.8,
            })

        # Time-driven predictions
        for signal in time_signals:
            predictions.append({
                "type": "time_pattern",
                "message": signal,
                "confidence": 0.9,
            })

        # Seasonal predictions
        for signal in seasonal_signals:
            predictions.append({
                "type": "seasonal",
                "message": signal,
                "confidence": 0.7,
            })

        # Hotspot area
        if area_counts:
            top_area = max(area_counts, key=area_counts.get)
            predictions.append({
                "type": "hotspot",
                "area": top_area,
                "count": area_counts[top_area],
                "message": f"{top_area} is a demand hotspot with {area_counts[top_area]} recent bookings",
            })

        duration_ms = int((time.time() - start_time) * 1000)

        reasoning = (
            f"Analyzed {len(recent_bookings)} recent bookings, "
            f"3-day weather forecast, and time patterns. "
            f"Generated {len(predictions)} demand predictions. "
            f"Weather signals: {len(weather_signals)} | "
            f"Time signals: {len(time_signals)} | "
            f"Seasonal signals: {len(seasonal_signals)}"
        )

        trace = {
            "id": trace_id,
            "session_id": session_id,
            "agent_name": AGENT_NAME,
            "step_number": 7,
            "input_data": {
                "bookings_analyzed": len(recent_bookings),
                "weather_days": 3,
            },
            "output_data": {
                "predictions_count": len(predictions),
                "top_service": max(service_counts, key=service_counts.get) if service_counts else "N/A",
                "weather_signals": len(weather_signals),
            },
            "tool_calls": [
                {"tool": "weather_forecast_3day", "status": "success"},
                {"tool": "booking_history_query", "status": "success"},
                {"tool": "demand_analysis", "status": "success"},
            ],
            "reasoning_text": reasoning,
            "duration_ms": duration_ms,
            "status": "success",
        }
        await save_agent_trace(trace)

        return {
            "success": True,
            "predictions": predictions,
            "service_counts": service_counts,
            "area_counts": area_counts,
            "weather": weather,
            "trace": trace,
        }

    except Exception as e:
        duration_ms = int((time.time() - start_time) * 1000)
        trace = {
            "id": trace_id,
            "session_id": session_id,
            "agent_name": AGENT_NAME,
            "step_number": 7,
            "output_data": {"error": str(e)},
            "reasoning_text": f"Demand prediction failed: {e}",
            "duration_ms": duration_ms,
            "status": "error",
        }
        await save_agent_trace(trace)
        return {"success": False, "error": str(e), "trace": trace}
