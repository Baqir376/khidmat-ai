"""
KaamSaaz — Agent 3: Matching Agent
Ranks providers using 5-factor weighted scoring with counterfactual reasoning.
"""
import time
import uuid
from services.trust_service import calculate_trust_score
from services.pricing_service import calculate_fair_price
from services.firebase_service import save_agent_trace

AGENT_NAME = "MatchingAgent"

# Scoring weights
WEIGHTS = {
    "distance": 0.25,
    "trust": 0.25,
    "price": 0.20,
    "rating": 0.15,
    "response_time": 0.15,
}


def _normalize(value: float, min_val: float, max_val: float) -> float:
    """Normalize value to 0-100 range."""
    if max_val == min_val:
        return 50.0
    return max(0, min(100, ((value - min_val) / (max_val - min_val)) * 100))


async def run_matching_agent(
    candidates: list[dict],
    intent: dict,
    session_id: str,
) -> dict:
    """
    Rank providers using weighted multi-factor scoring.
    Generates counterfactual reasoning for top selection.
    """
    start_time = time.time()
    trace_id = str(uuid.uuid4())[:12]

    try:
        if not candidates:
            return {
                "success": False,
                "error": "No candidates to rank",
                "scored_providers": [],
            }

        service_type = intent.get("service_type", "electrician")
        area = intent.get("location", "")
        time_str = intent.get("resolved_time", "09:00")
        urgency = intent.get("urgency", "normal")
        original_text = intent.get("original_text", "").lower()

        # Get fair price range for this service/area
        fair_price = calculate_fair_price(service_type, area, time_str, urgency)

        # AI Pricing Suitability Decision:
        # Determine if the task is likely short-duration or long-duration/complex
        short_keywords = [
            "leak", "leaking", "bulb", "change", "install", "quick", "chota", "leakage", 
            "clean single", "short", "fix", "repair", "replace", "switch", "plug", "button", 
            "capacitor", "tap", "nalka", "dhona", "chota kaam", "1 hour", "ek ghanta", "minor", 
            "small", "help", "fan repair"
        ]
        long_keywords = [
            "complete", "wiring", "fitting", "renovate", "full", "whole", "apartment", 
            "house", "building", "installation of 3 acs", "major", "ganda", "shadi", "wedding", 
            "makeup", "painting whole house", "rebuilding", "new installation", "large", "heavy"
        ]

        is_long = any(kw in original_text for kw in long_keywords)
        is_short = any(kw in original_text for kw in short_keywords)

        if is_long:
            optimal_pricing_type = "fixed_or_per_job"
        elif is_short:
            optimal_pricing_type = "hourly"
        else:
            optimal_pricing_type = "any"

        # Calculate raw values for normalization
        def get_active_rate(c):
            pt = c.get("pricing_type", "hourly")
            if pt == "fixed":
                return c.get("fixed_rate") or c.get("rate") or c.get("hourly_rate") or 1500
            elif pt == "per_job":
                return c.get("per_job_rate") or c.get("rate") or c.get("hourly_rate") or 1500
            else:
                return c.get("hourly_rate") or c.get("rate") or 1500

        distances = [c.get("distance_km", 10) for c in candidates]
        rates = [get_active_rate(c) for c in candidates]
        response_times = [c.get("avg_response_time_minutes", 30) for c in candidates]

        min_dist, max_dist = min(distances), max(distances)
        min_rate, max_rate = min(rates), max(rates)
        min_resp, max_resp = min(response_times), max(response_times)

        scored = []
        for candidate in candidates:
            # 1. Distance score (closer = higher, inverted)
            dist = candidate.get("distance_km", 10)
            dist_score = 100 - _normalize(dist, min_dist, max_dist)

            # 2. Trust score
            trust_result = calculate_trust_score(candidate)
            trust_score = trust_result["trust_score"]

            # 3. Price score (closer to fair min = higher)
            rate = get_active_rate(candidate)
            price_score = 100 - _normalize(rate, min_rate, max_rate)

            # 4. Rating score
            rating = candidate.get("rating", 3.0)
            rating_score = (rating / 5.0) * 100

            # 5. Response time score (faster = higher, inverted)
            resp = candidate.get("avg_response_time_minutes", 30)
            resp_score = 100 - _normalize(resp, min_resp, max_resp)

            # Composite weighted score
            composite = (
                WEIGHTS["distance"] * dist_score
                + WEIGHTS["trust"] * trust_score
                + WEIGHTS["price"] * price_score
                + WEIGHTS["rating"] * rating_score
                + WEIGHTS["response_time"] * resp_score
            )

            # Apply Dynamic AI Suitability Boost
            pricing_type = candidate.get("pricing_type", "hourly")
            suitability_boost = 0.0
            if optimal_pricing_type == "fixed_or_per_job" and pricing_type in ["fixed", "per_job"]:
                suitability_boost = 15.0
            elif optimal_pricing_type == "hourly" and pricing_type == "hourly":
                suitability_boost = 15.0

            composite = min(100.0, composite + suitability_boost)

            scored.append({
                **candidate,
                "match_score": round(composite, 2),
                "score_breakdown": {
                    "distance": round(dist_score, 1),
                    "trust": round(trust_score, 1),
                    "price": round(price_score, 1),
                    "rating": round(rating_score, 1),
                    "response_time": round(resp_score, 1),
                },
                "trust_details": trust_result,
                "fair_price_range": fair_price,
            })

        # Sort by composite score (highest first)
        scored.sort(key=lambda x: x["match_score"], reverse=True)

        # Generate counterfactual reasoning
        counterfactual = ""
        if len(scored) >= 2:
            top = scored[0]
            runner_up = scored[1]
            counterfactual = _generate_counterfactual(top, runner_up, WEIGHTS, optimal_pricing_type, original_text)
        elif len(scored) == 1:
            top = scored[0]
            pt_name = top.get("pricing_type", "hourly")
            rate_val = get_active_rate(top)
            rate_str = f"Rs {rate_val}/hr" if pt_name == "hourly" else (f"Rs {rate_val} (Fixed)" if pt_name == "fixed" else f"Rs {rate_val}/job")
            counterfactual = f"AI Pick: {top.get('name_en', 'Provider')} is the best match. They are only {top.get('distance_km', 1.5)}km away, rated {top.get('rating', 4.5)}⭐, and charge a suitable {rate_str}."

        duration_ms = int((time.time() - start_time) * 1000)

        top_provider = scored[0] if scored else {}
        def format_provider_rate(p):
            if not p:
                return "Rs 0"
            pt = p.get("pricing_type", "hourly")
            rate_val = get_active_rate(p)
            if pt == "fixed":
                return f"Rs {rate_val} (Fixed)"
            elif pt == "per_job":
                return f"Rs {rate_val}/job"
            else:
                return f"Rs {rate_val}/hr"

        provider_rate_str = format_provider_rate(top_provider)
        reasoning = (
            f"Ranked {len(scored)} providers. "
            f"Top match: {top_provider.get('name_en', 'N/A')} "
            f"(score: {top_provider.get('match_score', 0)}/100, "
            f"distance: {top_provider.get('distance_km', 0)}km, "
            f"rating: {top_provider.get('rating', 0)}⭐, "
            f"rate: {provider_rate_str}). "
            f"Fair price range: Rs {fair_price['min']}-{fair_price['max']}."
        )

        trace = {
            "id": trace_id,
            "session_id": session_id,
            "agent_name": AGENT_NAME,
            "step_number": 3,
            "input_data": {
                "candidates_count": len(candidates),
                "service_type": service_type,
                "weights": WEIGHTS,
                "optimal_pricing_type": optimal_pricing_type,
            },
            "output_data": {
                "ranked_count": len(scored),
                "top_provider": top_provider.get("name_en", ""),
                "top_score": top_provider.get("match_score", 0),
                "fair_price": fair_price,
            },
            "tool_calls": [
                {"tool": "trust_score_calc", "count": len(candidates)},
                {"tool": "fair_price_calc", "status": "success"},
                {"tool": "weighted_scoring", "status": "success"},
            ],
            "reasoning_text": reasoning,
            "duration_ms": duration_ms,
            "status": "success",
        }
        await save_agent_trace(trace)

        return {
            "success": True,
            "scored_providers": scored[:10],  # Top 10
            "fair_price": fair_price,
            "counterfactual": counterfactual,
            "trace": trace,
        }

    except Exception as e:
        duration_ms = int((time.time() - start_time) * 1000)
        trace = {
            "id": trace_id,
            "session_id": session_id,
            "agent_name": AGENT_NAME,
            "step_number": 3,
            "input_data": {"candidates_count": len(candidates)},
            "output_data": {"error": str(e)},
            "reasoning_text": f"Matching failed: {e}",
            "duration_ms": duration_ms,
            "status": "error",
        }
        await save_agent_trace(trace)
        return {"success": False, "error": str(e), "trace": trace}


def _generate_counterfactual(top: dict, runner_up: dict, weights: dict, optimal_pricing_type: str, original_text: str) -> str:
    """Generate counterfactual reasoning explaining why top was chosen."""
    top_name = top.get("name_en", "Provider A")
    ru_name = runner_up.get("name_en", "Provider B")
    top_score = top.get("match_score", 0)
    ru_score = runner_up.get("match_score", 0)

    top_pt = top.get("pricing_type", "hourly")
    ru_pt = runner_up.get("pricing_type", "hourly")

    def get_rate(p):
        pt = p.get("pricing_type", "hourly")
        if pt == "fixed":
            return p.get("fixed_rate") or p.get("rate") or p.get("hourly_rate") or 1500
        elif pt == "per_job":
            return p.get("per_job_rate") or p.get("rate") or p.get("hourly_rate") or 1500
        else:
            return p.get("hourly_rate") or p.get("rate") or 1500

    top_rate = get_rate(top)
    ru_rate = get_rate(runner_up)

    top_rate_str = f"Rs {top_rate}/hr" if top_pt == "hourly" else (f"Rs {top_rate} (Fixed)" if top_pt == "fixed" else f"Rs {top_rate}/job")
    ru_rate_str = f"Rs {ru_rate}/hr" if ru_pt == "hourly" else (f"Rs {ru_rate} (Fixed)" if ru_pt == "fixed" else f"Rs {ru_rate}/job")

    # Dynamic pricing explanation
    pricing_explanation = ""
    if optimal_pricing_type == "hourly":
        pricing_explanation = (
            f"Your request suggests a quick/short task. We selected {top_name} because their Hourly pricing structure ({top_rate_str}) "
            f"is much more suitable and budget-friendly for minor work than flat rates."
        )
    elif optimal_pricing_type == "fixed_or_per_job":
        pricing_explanation = (
            f"Your request suggests a major/complex task. We selected {top_name} because their Fixed/Per-Job pricing structure ({top_rate_str}) "
            f"protects you from hourly billing escalations for long-duration jobs."
        )
    else:
        pricing_explanation = (
            f"We selected {top_name} as the best match. They offer a highly competitive rate of {top_rate_str}."
        )

    parts = [
        f"AI Pick: {pricing_explanation}",
        f"They scored {top_score}/100 over {ru_name} (score: {ru_score}, rate: {ru_rate_str})."
    ]

    # Compare each factor
    t_bd = top.get("score_breakdown", {})
    r_bd = runner_up.get("score_breakdown", {})

    advantages = []
    disadvantages = []

    for factor, weight in weights.items():
        t_val = t_bd.get(factor, 50)
        r_val = r_bd.get(factor, 50)
        diff = t_val - r_val

        if diff > 10:
            advantages.append(f"{factor} (+{round(diff)})")
        elif diff < -10:
            disadvantages.append(f"{factor} ({round(diff)})")

    if advantages:
        parts.append(f"Key advantages: {', '.join(advantages)}.")
    if disadvantages:
        parts.append(f"Trade-offs accepted: {', '.join(disadvantages)}.")

    # Add distance details
    top_dist = top.get("distance_km", 1.5)
    ru_dist = runner_up.get("distance_km", 2.5)
    if ru_dist > top_dist:
        parts.append(f"Also, {top_name} is {round(ru_dist - top_dist, 1)}km closer to you than {ru_name}.")

    return " ".join(parts)
