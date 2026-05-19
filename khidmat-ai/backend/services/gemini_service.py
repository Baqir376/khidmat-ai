"""
Khidmat AI — Gemini Service
Wrapper for Google Generative AI SDK. Handles all LLM calls.
"""
import json
from typing import Optional
from config import config

_model = None

try:
    import google.generativeai as genai
    if config.GEMINI_API_KEY:
        genai.configure(api_key=config.GEMINI_API_KEY)
        _model = genai.GenerativeModel(config.GEMINI_MODEL)
        print(f"[Gemini] Connected ({config.GEMINI_MODEL})")
    else:
        print("[Gemini] No API key — using mock responses")
except Exception as e:
    print(f"[Gemini] Init failed ({e}) — using mock responses")


async def generate_text(
    prompt: str,
    system_instruction: Optional[str] = None,
    temperature: float = 0.3,
    max_tokens: int = 2048,
) -> str:
    """Generate text from Gemini. Falls back to mock if no API key or on timeout."""
    if _model:
        try:
            import asyncio
            full_prompt = f"{system_instruction}\n\n{prompt}" if system_instruction else prompt

            def _call():
                return _model.generate_content(
                    full_prompt,
                    generation_config={
                        "temperature": temperature,
                        "max_output_tokens": max_tokens,
                    },
                ).text

            # Run blocking SDK call in thread pool with 8-second timeout
            response_text = await asyncio.wait_for(
                asyncio.to_thread(_call),
                timeout=8.0
            )
            return response_text
        except Exception as e:
            print(f"[Gemini] Error/Timeout ({type(e).__name__}) — using smart fallback")
            return _mock_response(full_prompt)
    else:
        full_prompt = f"{system_instruction}\n\n{prompt}" if system_instruction else prompt
        return _mock_response(full_prompt)


async def generate_json(
    prompt: str,
    system_instruction: Optional[str] = None,
    temperature: float = 0.2,
) -> dict:
    """Generate structured JSON from Gemini."""
    json_prompt = (
        f"{prompt}\n\n"
        "IMPORTANT: Respond ONLY with valid JSON. No markdown, no explanation."
    )
    raw = await generate_text(json_prompt, system_instruction, temperature)

    # Clean markdown code fences if present
    raw = raw.strip()
    if raw.startswith("```"):
        raw = raw.split("\n", 1)[-1]
    if raw.endswith("```"):
        raw = raw.rsplit("```", 1)[0]
    raw = raw.strip()

    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        # Try to extract JSON from response
        start = raw.find("{")
        end = raw.rfind("}") + 1
        if start >= 0 and end > start:
            try:
                return json.loads(raw[start:end])
            except json.JSONDecodeError:
                pass
        return {"raw_response": raw, "parse_error": True}


def _mock_response(prompt: str) -> str:
    """Fallback response when Gemini API is unavailable/quota exceeded.
    Uses keyword matching on the actual user input to detect real service type."""
    import re
    prompt_lower = prompt.lower()

    if "administrator:" in prompt_lower or "copilot" in prompt_lower:
        total_bookings = "7"
        active_providers = "4"
        gmv = "PKR 8,800"
        
        tb_match = re.search(r'Total Bookings:\s*(\d+)', prompt)
        if tb_match:
            total_bookings = tb_match.group(1)
            
        ap_match = re.search(r'Active Providers:\s*(\d+)', prompt)
        if ap_match:
            active_providers = ap_match.group(1)
            
        gmv_match = re.search(r'Gross Merchandise Value \(GMV\):\s*([^\n\r]+)', prompt)
        if gmv_match:
            gmv = gmv_match.group(1).strip()

        # Parse live providers list from prompt context
        providers_list = []
        try:
            providers_match = re.search(r'2\. Active Providers Registry \(Earnings & Performance\):\s*(\[.*?\])', prompt, re.DOTALL)
            if providers_match:
                providers_list = json.loads(providers_match.group(1))
        except Exception:
            pass

        # Parse live bookings ledger from prompt context
        bookings_list = []
        try:
            bookings_match = re.search(r'3\. Bookings Ledger:\s*(\[.*?\])', prompt, re.DOTALL)
            if bookings_match:
                bookings_list = json.loads(bookings_match.group(1))
        except Exception:
            pass

        # Check last line of the prompt to detect the language of the current user message
        prompt_lines = [line.strip() for line in prompt.split("\n") if line.strip()]
        last_line = prompt_lines[-1].lower() if prompt_lines else prompt_lower

        # Roman Urdu Detection Check
        roman_urdu_words = ["kaun", "kitne", "kitni", "kon", "kya", "kia", "kis", "ne", "kamaya", "kamaye", "hai", "hain", "sabse", "sab se", "zyada", "ziada", "kaunsa", "konsa", "karnay", "kiya", "liye", "tha", "thi", "gaya", "gayi", "konse", "kamaya", "earn kiya", "urdu", "roman"]
        is_roman_urdu = any(word in last_line for word in roman_urdu_words)

        # Dynamic calculations based on parsed context
        if providers_list:
            # Basic provider aggregates
            num_providers = len(providers_list)
            avg_income = sum(p.get("total_income_pkr", 0) for p in providers_list) / num_providers if num_providers else 0
            avg_rating = sum(p.get("rating", 0.0) for p in providers_list) / num_providers if num_providers else 0.0
            avg_jobs = sum(p.get("jobs_completed", 0) for p in providers_list) / num_providers if num_providers else 0
            
            top_by_jobs = max(providers_list, key=lambda x: x.get("jobs_completed", 0))
            top_by_income = max(providers_list, key=lambda x: x.get("total_income_pkr", 0))
            
            lowest_by_income = min(providers_list, key=lambda x: x.get("total_income_pkr", 0))
            lowest_by_jobs = min(providers_list, key=lambda x: x.get("jobs_completed", 0))
            
            top_by_rating = max(providers_list, key=lambda x: x.get("rating", 0.0))
            lowest_by_rating = min(providers_list, key=lambda x: x.get("rating", 5.0))
            
            # Specialties count
            specialties = {}
            for p in providers_list:
                spec = p.get("specialty", "General")
                specialties[spec] = specialties.get(spec, 0) + 1
                
            # Available providers online list
            available_provs = [p.get("name") for p in providers_list if p.get("is_available")]
            
            # Check for a specific provider query
            queried_provider = None
            for p in providers_list:
                if p.get("name", "").lower() in last_line:
                    queried_provider = p
                    break
            
            if queried_provider:
                name = queried_provider.get("name")
                jobs = queried_provider.get("jobs_completed", 0)
                income = queried_provider.get("total_income_pkr", 0)
                rating = queried_provider.get("rating", 5.0)
                specialty = queried_provider.get("specialty", "provider")
                available_status = "Available/Online" if queried_provider.get("is_available") else "Offline/Busy"
                available_status_ur = "Online (Available)" if queried_provider.get("is_available") else "Offline (Busy)"
                
                if is_roman_urdu:
                    return f"Live telemetry ke mutabiq, {name} ({specialty}) ne total {jobs} jobs mukammal kiye hain aur PKR {income:,} kamaye hain. Unki average rating {rating} hai aur woh is waqt {available_status_ur} hain."
                else:
                    return f"According to real-time telemetry, {name} ({specialty}) has completed a total of {jobs} jobs and earned PKR {income:,} with an average rating of {rating}. They are currently {available_status}."

            # Query: Availability (Who is available / online?)
            available_keywords = ["available", "online", "free right now", "kon free hai", "available providers", "online kaun hai", "active providers list", "is available"]
            if any(kw in last_line for kw in available_keywords):
                names_str = ", ".join(available_provs) if available_provs else "None"
                if is_roman_urdu:
                    return f"Live telemetry status ke mutabiq, is waqt {len(available_provs)} providers online aur active hain: {names_str}."
                else:
                    return f"Based on live heartbeat telemetry, there are currently {len(available_provs)} providers available online: {names_str}."

            # Query: Average Earnings / Income
            average_income_keywords = ["average income", "average earning", "avg income", "avg earning", "average kamai", "avg kamai", "average earnings"]
            if any(kw in last_line for kw in average_income_keywords):
                if is_roman_urdu:
                    return f"Live database analysis ke mutabiq, active providers ki overall average income PKR {avg_income:,.2f} hai."
                else:
                    return f"Based on database records, the average income generated by an active provider on our platform is PKR {avg_income:,.2f}."

            # Query: Average Ratings
            average_rating_keywords = ["average rating", "avg rating", "average feedback", "avg feedback", "avg star", "average star", "ratings average"]
            if any(kw in last_line for kw in average_rating_keywords):
                if is_roman_urdu:
                    return f"Customer ratings ledger ke mutabiq, active providers ki overall average rating {avg_rating:.2f} stars hai."
                else:
                    return f"Based on customer feedback loops, the average rating for active providers on the marketplace is {avg_rating:.2f} stars."

            # Query: Average Jobs Completed
            average_jobs_keywords = ["average jobs", "avg jobs", "average task", "avg task", "average completed", "avg completed"]
            if any(kw in last_line for kw in average_jobs_keywords):
                if is_roman_urdu:
                    return f"System telemetry ke mutabiq, active providers ne average {avg_jobs:.1f} jobs mukammal kiye hain."
                else:
                    return f"Based on system metrics, the average number of completed jobs per provider is {avg_jobs:.1f}."

            # Query: Best/Worst performing service type (Specialty)
            specialty_query_keywords = ["specialty", "service type", "popular specialty", "kaunsi service", "best performing specialty", "top specialty", "sab se zyada specialist"]
            if any(kw in last_line for kw in specialty_query_keywords):
                sorted_specs = sorted(specialties.items(), key=lambda x: x[1], reverse=True)
                top_spec, top_count = sorted_specs[0] if sorted_specs else ("None", 0)
                if is_roman_urdu:
                    return f"Active registry ke mutabiq, platform par sab se zyada providers '{top_spec}' specialty ke hain ({top_count} registered active providers)."
                else:
                    return f"According to the active registry, the most popular provider specialty is '{top_spec}' with {top_count} active service providers registered."

            # Sab se kam income (Lowest income)
            lowest_income_keywords = ["kam income", "kam kamai", "lowest income", "least income", "lowest earner", "least earner", "kam kamaya", "sabse kam kamaya", "kam earning", "sab se kam income", "sab se kam kamaya"]
            if any(kw in last_line for kw in lowest_income_keywords):
                name = lowest_by_income.get("name")
                jobs = lowest_by_income.get("jobs_completed", 0)
                income = lowest_by_income.get("total_income_pkr", 0)
                specialty = lowest_by_income.get("specialty", "provider")
                if is_roman_urdu:
                    return f"Live database records ke mutabiq, sab se kam income {name} ({specialty}) ki hai, jinhon ne total PKR {income:,} kamaye hain across {jobs} jobs."
                else:
                    return f"Based on live database telemetry, the provider with the lowest income is {name} ({specialty}) with a total income of PKR {income:,} across {jobs} jobs."

            # Sab se kam rating (Lowest rating)
            lowest_rating_keywords = ["kam rating", "worst rating", "lowest rating", "least rating", "kam star", "sabse kam rating", "sab se kam rating"]
            if any(kw in last_line for kw in lowest_rating_keywords):
                name = lowest_by_rating.get("name")
                specialty = lowest_by_rating.get("specialty", "provider")
                rating = lowest_by_rating.get("rating", 5.0)
                if is_roman_urdu:
                    return f"Feedback records ke mutabiq, sab se kam rating {name} ({specialty}) ki hai jo keh {rating} stars hai."
                else:
                    return f"According to feedback records, the provider with the lowest rating is {name} ({specialty}) with a rating of {rating} stars."

            # Sab se zyada rating (Highest rating)
            highest_rating_keywords = ["zyada rating", "ziada rating", "highest rating", "top rated", "best rating", "best feedback", "sabse zyada rating", "sab se zyada rating"]
            if any(kw in last_line for kw in highest_rating_keywords):
                name = top_by_rating.get("name")
                specialty = top_by_rating.get("specialty", "provider")
                rating = top_by_rating.get("rating", 5.0)
                if is_roman_urdu:
                    return f"Feedback records ke mutabiq, sab se zyada rating {name} ({specialty}) ki hai jo keh {rating} stars hai."
                else:
                    return f"According to feedback records, the top-rated provider is {name} ({specialty}) with a stellar rating of {rating} stars."

            # Sab se kam jobs (Least jobs)
            least_jobs_keywords = ["kam jobs", "least jobs", "fewest jobs", "lowest jobs", "sabse kam kaam", "sab se kam jobs", "sab se kam kaam"]
            if any(kw in last_line for kw in least_jobs_keywords):
                name = lowest_by_jobs.get("name")
                specialty = lowest_by_jobs.get("specialty", "provider")
                jobs = lowest_by_jobs.get("jobs_completed", 0)
                if is_roman_urdu:
                    return f"Live telemetry ke mutabiq, sab se kam jobs {name} ({specialty}) ne ki hain jo keh total {jobs} jobs hain."
                else:
                    return f"Based on live telemetry, the provider with the fewest completed jobs is {name} ({specialty}) with {jobs} jobs."

            # Sab se zyada jobs (Most jobs)
            most_jobs_keywords = ["zyada jobs", "ziada jobs", "most jobs", "highest jobs", "most completed", "most active", "sabse zyada kaam", "sab se zyada jobs", "sab se zyada kaam"]
            if any(kw in last_line for kw in most_jobs_keywords):
                name = top_by_jobs.get("name")
                specialty = top_by_jobs.get("specialty", "provider")
                jobs = top_by_jobs.get("jobs_completed", 0)
                if is_roman_urdu:
                    return f"Live telemetry ke mutabiq, sab se zyada jobs {name} ({specialty}) ne ki hain jo keh total {jobs} jobs hain."
                else:
                    return f"Based on live telemetry, the provider with the most completed jobs is {name} ({specialty}) with {jobs} jobs."

            # Sab se zyada income (Highest income)
            highest_income_keywords = ["zyada income", "ziada income", "highest income", "most income", "highest earner", "top earner", "top earnings", "zyada kamaya", "sabse zyada kamaya", "zyada earning", "sab se zyada income"]
            if any(kw in last_line for kw in highest_income_keywords):
                name = top_by_income.get("name")
                jobs = top_by_income.get("jobs_completed", 0)
                income = top_by_income.get("total_income_pkr", 0)
                specialty = top_by_income.get("specialty", "provider")
                if is_roman_urdu:
                    return f"Live database records ke mutabiq, sab se zyada income {name} ({specialty}) ki hai, jinhon ne total PKR {income:,} kamaye hain across {jobs} jobs."
                else:
                    return f"Based on live database telemetry, the provider with the highest income is {name} ({specialty}) with a total income of PKR {income:,} across {jobs} jobs."

        # Parse live bookings stats from bookings_list
        num_bookings = len(bookings_list)
        completed_bookings = [b for b in bookings_list if b.get("status", "").lower() in ["completed", "complete"]]
        cancelled_bookings = [b for b in bookings_list if b.get("status", "").lower() in ["cancelled", "cancel"]]
        pending_bookings = [b for b in bookings_list if b.get("status", "").lower() in ["pending", "confirmed", "confirm"]]
        
        total_rev_from_bookings = sum(b.get("price_pkr", 0) for b in bookings_list if b.get("status", "").lower() not in ["cancelled", "cancel"])
        avg_booking_price = total_rev_from_bookings / len(bookings_list) if bookings_list else 0.0

        # Query: Booking status breakdown / count checks
        status_keywords = ["status breakdown", "booking breakdown", "cancelled bookings", "completed bookings", "pending bookings", "confirm bookings", "cancel kitni", "kitne booking cancel", "kitne booking complete", "bookings detail", "bookings summary"]
        if any(kw in last_line for kw in status_keywords):
            if is_roman_urdu:
                return f"Live bookings breakdown yeh hai: Total {num_bookings} bookings registered hain, jisme se {len(completed_bookings)} Completed hain, {len(pending_bookings)} Confirmed/Pending hain aur {len(cancelled_bookings)} Cancelled hain."
            else:
                return f"Here is the active booking breakdown: out of {num_bookings} total bookings in our ledger, {len(completed_bookings)} are Completed, {len(pending_bookings)} are Confirmed/Pending, and {len(cancelled_bookings)} are Cancelled."

        # Query: Average Booking Price / GMV / Total Revenue
        booking_revenue_keywords = ["average booking", "average price", "avg booking price", "avg price", "average booking value", "gmv", "revenue", "gross merchandise value", "total earnings of marketplace", "earnings total"]
        if any(kw in last_line for kw in booking_revenue_keywords):
            if is_roman_urdu:
                return f"System statistics ke mutabiq, gross merchandise value (GMV) PKR {gmv} hai aur average booking price/value PKR {avg_booking_price:,.2f} hai."
            else:
                return f"According to system logs, the Gross Merchandise Value (GMV) is PKR {gmv} and the average value per booking on the platform is PKR {avg_booking_price:,.2f}."

        # Query: Agent Success Rate / Autonomous Coordinator performance
        success_rate_keywords = ["success rate", "performance rate", "autonomous rate", "agent success", "booking success", "agent performance"]
        if any(kw in last_line for kw in success_rate_keywords):
            if is_roman_urdu:
                return f"Marketplace AI coordinator (orchestrator agent) ka overall success rate 99% hai, jo bookings aur provider dispatch process ko completely manage karta hai."
            else:
                return f"The autonomous agent orchestrator system maintains an active success rate of 99%, coordinating real-time bookings dispatch loops and citizen-provider matchmaking."

        if "booking" in last_line or "status" in last_line or "total" in last_line or "kitni" in last_line or "kitne" in last_line:
            if is_roman_urdu:
                return f"System ledger ke mutabiq, total {total_bookings} bookings registered hain aur is waqt gross merchandise value (GMV) {gmv} hai."
            else:
                return f"According to the live bookings ledger, there are a total of {total_bookings} bookings registered on the platform. The gross merchandise value (GMV) generated is {gmv}."

        if is_roman_urdu:
            return f"Assalam-o-Alaikum! Main aapka Khidmat Copilot hoon. Currently, {active_providers} active providers registered hain, total {total_bookings} bookings hain aur GMV {gmv} hai. Main aapki kis tarah madad kar sakta hoon?"
        else:
            return f"Hello Administrator! I am your Khidmat Copilot. Currently, there are {active_providers} active providers registered, {total_bookings} total bookings in our ledger, and a GMV of {gmv}. Let me know if you need any other specific breakdown!"

    search_text = prompt_lower
    # Try to match user input enclosed in quotes followed by input type (very specific, matches prompt structure)
    user_input_match = re.search(r'user input:\s*"(.*?)"\s*input type:', prompt_lower, re.DOTALL)
    if user_input_match:
        search_text = user_input_match.group(1)
    else:
        # Fallback to general user input regex with DOTALL to support newlines
        user_input_match = re.search(r'user input:\s*"(.*?)"', prompt_lower, re.DOTALL)
        if user_input_match:
            search_text = user_input_match.group(1)
        else:
            # Fallback: check if "user input:" exists and take everything after it
            parts = re.split(r'user input:\s*', prompt_lower)
            if len(parts) > 1:
                search_text = parts[-1]

    # ---- Smart service detection from the actual user message ----
    service_keywords = {
        "plumber": ["plumber", "nalka", "pipe", "drain", "nala", "pani", "plumb"],
        "electrician": ["electrician", "bijli", "electric", "wiring", "switch", "fan", "light", "socket"],
        "ac_mechanic": ["ac_mechanic", "ac", "air condition", "cooling", "thanda", "ac wala", "mechanic"],
        "house_maid": ["house_maid", "maid", "safai", "cleaning", "kaam wali", "dhona", "sweeper", "dusting"],
        "carpenter": ["carpenter", "badhai", "wood", "furniture", "almari", "door"],
        "painter": ["painter", "paint", "rang", "wall", "colour", "rangan"],
        "gardener": ["gardener", "mali", "lawn", "plant", "pauda", "ghas", "grass"],
        "tutor": ["tutor", "teacher", "tuition", "padhai", "sir", "madam", "study"],
        "beautician": ["beautician", "beauty", "makeup", "parlour", "mehnd", "facial", "hair"],
        "generator": ["generator", "genset"],
        "welder": ["welder", "weld", "loha", "iron", "gate"],
        "tiler": ["tiler", "tile", "marble", "floor"],
    }
    
    detected_service = "plumber"  # safe default
    for stype, keywords in service_keywords.items():
        found = False
        for kw in keywords:
            pattern = rf"\b{re.escape(kw)}\b" if kw.isalnum() else re.escape(kw)
            if re.search(pattern, search_text):
                detected_service = stype
                found = True
                break
        if found:
            break

    # ---- Location detection ----
    detected_location = "Karachi"
    location_keywords = {
        "Gulberg": ["gulberg"],
        "DHA": ["dha", "defence"],
        "Gulshan-e-Iqbal": ["gulshan"],
        "Clifton": ["clifton"],
        "North Nazimabad": ["north nazimabad", "nazimabad"],
        "G-10": ["g-10", "g10"],
        "F-7": ["f-7", "f7"],
        "Rawalpindi": ["rawalpindi", "pindi"],
        "Lahore": ["lahore"],
        "Islamabad": ["islamabad"],
    }
    for loc, kws in location_keywords.items():
        found = False
        for kw in kws:
            pattern = rf"\b{re.escape(kw)}\b" if kw.isalnum() else re.escape(kw)
            if re.search(pattern, search_text):
                detected_location = loc
                found = True
                break
        if found:
            break

    # ---- Urgency detection ----
    urgency = "normal"
    for w in ["abhi", "jaldi", "urgent", "emergency", "fori", "quickly"]:
        pattern = rf"\b{re.escape(w)}\b"
        if re.search(pattern, search_text):
            urgency = "urgent"
            break

    if "intent" in prompt_lower or "extract" in prompt_lower or "parse" in prompt_lower:
        return json.dumps({
            "service_type": detected_service,
            "location": detected_location,
            "date": "today",
            "time": "now" if urgency == "urgent" else "morning",
            "urgency": urgency,
            "language": "roman_ur",
            "additional_details": "",
            "confidence": 0.75,
        })
    elif "negotiat" in prompt_lower:
        return json.dumps({
            "counter_offer": 1800,
            "reasoning": "Market rate for this area is Rs 1500-2200",
            "suggestion": "Rs 1800 is fair for this service and location",
        })
    elif "followup" in prompt_lower or "follow" in prompt_lower:
        return json.dumps({
            "reminder_message": "Aapka appointment 1 ghante baad hai",
            "satisfaction_question": "Service kaisi rahi? 1-5 stars dein",
        })
    else:
        return json.dumps({"response": "Service request received", "status": "ok"})

