"""
KaamSaaz — Agent 4: Negotiation Agent
Assesses provider pricing against market rates and suggests counter-offers.
"""
import time
import uuid
from services.gemini_service import generate_json
from services.pricing_service import assess_price
from services.firebase_service import save_agent_trace

AGENT_NAME = "NegotiationAgent"


async def run_negotiation_agent(
    provider: dict,
    intent: dict,
    fair_price: dict,
    session_id: str,
) -> dict:
    """
    Assess provider's quoted price and negotiate if above market rate.
    Returns price assessment, counter-offer if needed, and negotiation log.
    """
    start_time = time.time()
    trace_id = str(uuid.uuid4())[:12]

    try:
        def get_active_rate(c):
            pt = c.get("pricing_type", "hourly")
            if pt == "fixed":
                return c.get("fixed_rate") or c.get("rate") or c.get("hourly_rate") or 1500
            elif pt == "per_job":
                return c.get("per_job_rate") or c.get("rate") or c.get("hourly_rate") or 1500
            else:
                return c.get("hourly_rate") or c.get("rate") or 1500

        quoted_price = get_active_rate(provider)
        provider_name = provider.get("name_en", "Provider")
        service_type = intent.get("service_type", "")

        # Safely read fair_price fields regardless of which key convention was used
        fp_value = fair_price.get("fair_price") or fair_price.get("fair") or quoted_price
        fp_min   = fair_price.get("min_price")  or fair_price.get("min")  or int(quoted_price * 0.7)
        fp_max   = fair_price.get("max_price")  or fair_price.get("max")  or int(quoted_price * 1.3)
        fp_breakdown = fair_price.get("breakdown", "Market rate estimate")

        # Assess price against market range
        safe_fair_price = {"min": fp_min, "max": fp_max, "fair": fp_value, "breakdown": fp_breakdown}
        assessment = assess_price(quoted_price, safe_fair_price)

        negotiation_log = []

        if assessment["negotiation_needed"]:
            prompt = f"""You are negotiating price for a {service_type} service in Pakistan.

Provider: {provider_name}
Quoted Price: Rs {quoted_price}
Fair Market Range: Rs {fp_min} - Rs {fp_max}

Generate a respectful counter-offer in Roman Urdu style.
Return JSON with: counter_offer_price, message_to_provider, message_to_citizen, reasoning"""

            ai_response = await generate_json(prompt)

            counter_offer = ai_response.get("counter_offer_price", fp_max)
            negotiation_log.append({
                "step": "initial_quote",
                "price": quoted_price,
                "from": "provider",
            })
            negotiation_log.append({
                "step": "counter_offer",
                "price": counter_offer,
                "from": "system",
                "message": ai_response.get("message_to_provider", ""),
            })
            negotiation_log.append({
                "step": "agreed",
                "price": counter_offer,
                "from": "system",
                "reasoning": ai_response.get("reasoning", "Market rate applied"),
            })

            final_price = counter_offer
        else:
            final_price = quoted_price
            negotiation_log.append({
                "step": "accepted",
                "price": quoted_price,
                "from": "system",
                "reasoning": assessment["message"],
            })

        duration_ms = int((time.time() - start_time) * 1000)

        reasoning = (
            f"Provider quoted Rs {quoted_price}. "
            f"Market range: Rs {fp_min}-{fp_max}. "
            f"Assessment: {assessment['assessment']}. "
            f"Final price: Rs {final_price}. "
            f"{'Negotiation applied.' if assessment['negotiation_needed'] else 'Price accepted as fair.'}"
        )

        trace = {
            "id": trace_id,
            "session_id": session_id,
            "agent_name": AGENT_NAME,
            "step_number": 4,
            "input_data": {
                "quoted_price": quoted_price,
                "fair_range": fair_price,
                "provider": provider_name,
            },
            "output_data": {
                "final_price": final_price,
                "assessment": assessment["assessment"],
                "negotiation_needed": assessment["negotiation_needed"],
            },
            "tool_calls": [
                {"tool": "price_assessment", "status": "success"},
                {"tool": "gemini_negotiation", "status": "success" if assessment["negotiation_needed"] else "skipped"},
            ],
            "reasoning_text": reasoning,
            "duration_ms": duration_ms,
            "status": "success",
        }
        await save_agent_trace(trace)

        return {
            "success": True,
            "final_price": final_price,
            "original_price": quoted_price,
            "assessment": assessment,
            "negotiation_log": negotiation_log,
            "price_negotiated": assessment["negotiation_needed"],
            "trace": trace,
        }

    except Exception as e:
        duration_ms = int((time.time() - start_time) * 1000)
        print(f"[NegotiationAgent] Error: {e} — returning provider rate as fallback")
        # Return fast fallback without hitting Firestore
        pt = provider.get("pricing_type", "hourly")
        fallback_price = provider.get("fixed_rate") or provider.get("rate") or provider.get("hourly_rate") or 1500 if pt == "fixed" else \
                         provider.get("per_job_rate") or provider.get("rate") or provider.get("hourly_rate") or 1500 if pt == "per_job" else \
                         provider.get("hourly_rate") or provider.get("rate") or 1500
        return {
            "success": True,
            "final_price": fallback_price,
            "original_price": fallback_price,
            "assessment": {"assessment": "error_fallback", "negotiation_needed": False, "message": str(e)},
            "negotiation_log": [{"step": "accepted", "price": fallback_price, "from": "system", "reasoning": "Fallback: provider rate accepted"}],
            "price_negotiated": False,
            "trace": {"agent_name": AGENT_NAME, "status": "fallback", "duration_ms": duration_ms},
        }
