"""
KaamSaaz — Weather Service
Uses Open-Meteo API (free, no key required) for real weather data.
Used by DiscoveryAgent to flag outdoor service risks and DemandAgent for predictions.
"""
import httpx
from typing import Optional


OPEN_METEO_BASE = "https://api.open-meteo.com/v1/forecast"

# Karachi default coordinates
DEFAULT_LAT = 24.8607
DEFAULT_LNG = 67.0099


async def get_weather_forecast(
    lat: float = DEFAULT_LAT,
    lng: float = DEFAULT_LNG,
    days: int = 1,
) -> dict:
    """
    Get weather forecast from Open-Meteo.
    Returns temperature, precipitation, and weather conditions.
    """
    try:
        params = {
            "latitude": lat,
            "longitude": lng,
            "daily": "temperature_2m_max,temperature_2m_min,precipitation_sum,weathercode",
            "current_weather": "true",
            "timezone": "Asia/Karachi",
            "forecast_days": days,
        }

        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.get(OPEN_METEO_BASE, params=params)
            response.raise_for_status()
            data = response.json()

        current = data.get("current_weather", {})
        daily = data.get("daily", {})

        result = {
            "current_temp": current.get("temperature"),
            "current_windspeed": current.get("windspeed"),
            "current_weathercode": current.get("weathercode", 0),
            "current_description": _weathercode_to_text(current.get("weathercode", 0)),
            "forecast": [],
        }

        # Parse daily forecasts
        dates = daily.get("time", [])
        max_temps = daily.get("temperature_2m_max", [])
        min_temps = daily.get("temperature_2m_min", [])
        precip_sums = daily.get("precipitation_sum", [])
        codes = daily.get("weathercode", [])

        for i in range(len(dates)):
            result["forecast"].append({
                "date": dates[i],
                "temp_max": max_temps[i] if i < len(max_temps) else None,
                "temp_min": min_temps[i] if i < len(min_temps) else None,
                "precipitation_mm": precip_sums[i] if i < len(precip_sums) else 0,
                "weathercode": codes[i] if i < len(codes) else 0,
                "description": _weathercode_to_text(codes[i] if i < len(codes) else 0),
            })

        return result

    except Exception as e:
        # Weather failure is non-critical — return safe defaults
        return {
            "current_temp": 35,
            "current_windspeed": 10,
            "current_weathercode": 0,
            "current_description": "Clear sky",
            "forecast": [{"date": "unknown", "temp_max": 35, "precipitation_mm": 0, "description": "Clear sky"}],
            "error": str(e),
        }


def check_outdoor_risk(
    weather: dict,
    service_type: str,
    day_index: int = 0,
) -> Optional[str]:
    """
    Check if weather poses a risk for outdoor services.
    Returns warning string or None if safe.
    """
    outdoor_services = {"painter", "welder", "tiler", "carpenter"}

    if service_type not in outdoor_services:
        return None

    forecast = weather.get("forecast", [])
    if not forecast or day_index >= len(forecast):
        return None

    day = forecast[day_index]
    rain_mm = day.get("precipitation_mm", 0)
    temp_max = day.get("temp_max", 35)

    warnings = []

    if rain_mm and rain_mm > 5:
        warnings.append(
            f"Weather warning: {rain_mm}mm rain expected. "
            f"Outdoor {service_type} work may be affected."
        )

    if temp_max and temp_max > 45:
        warnings.append(
            f"Heat warning: {temp_max}°C expected. "
            f"Outdoor work may be unsafe — schedule early morning."
        )

    if temp_max and temp_max > 42:
        warnings.append(
            f"High temperature alert: {temp_max}°C forecast. "
            f"AC demand surge expected — book early."
        )

    return " | ".join(warnings) if warnings else None


def get_demand_signals(weather: dict) -> list[str]:
    """
    Extract demand prediction signals from weather data.
    Used by DemandPredictionAgent.
    """
    signals = []
    forecast = weather.get("forecast", [])

    for day in forecast:
        temp_max = day.get("temp_max", 30)
        rain = day.get("precipitation_mm", 0)
        date = day.get("date", "")

        if temp_max and temp_max > 40:
            signals.append(
                f"{date}: High temp {temp_max}°C — AC technician demand spike expected"
            )
        if temp_max and temp_max > 44:
            signals.append(
                f"{date}: Extreme heat {temp_max}°C — Enable surge +15% for AC services"
            )
        if rain and rain > 10:
            signals.append(
                f"{date}: Heavy rain {rain}mm — Plumber demand likely (drainage issues)"
            )
        if rain and rain > 20:
            signals.append(
                f"{date}: Flooding risk {rain}mm — Emergency plumber demand expected"
            )

    return signals


def _weathercode_to_text(code: int) -> str:
    """Convert WMO weather code to human-readable text."""
    weather_codes = {
        0: "Clear sky",
        1: "Mainly clear",
        2: "Partly cloudy",
        3: "Overcast",
        45: "Foggy",
        48: "Depositing rime fog",
        51: "Light drizzle",
        53: "Moderate drizzle",
        55: "Dense drizzle",
        61: "Slight rain",
        63: "Moderate rain",
        65: "Heavy rain",
        71: "Slight snow",
        73: "Moderate snow",
        75: "Heavy snow",
        80: "Slight rain showers",
        81: "Moderate rain showers",
        82: "Violent rain showers",
        95: "Thunderstorm",
        96: "Thunderstorm with slight hail",
        99: "Thunderstorm with heavy hail",
    }
    return weather_codes.get(code, f"Weather code {code}")
