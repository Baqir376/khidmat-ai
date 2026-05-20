"""
Khidmat AI — Provider Routes
Provider search, nearby providers, and profile management.
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
import uuid
import datetime
from services.firebase_service import (
    get_document, query_collection, get_providers_by_service,
    create_document, update_document
)
from services.maps_service import haversine_km, estimate_eta_minutes, geocode_address, reverse_geocode
from services.trust_service import calculate_trust_score
from models.schemas import ReviewCreate

router = APIRouter()

class ProviderRegisterRequest(BaseModel):
    name_en: str
    phone: str
    service_type_id: str
    hourly_rate: int
    area_name: str
    lat: float = 24.8607
    lng: float = 67.0099
    gender: str = "male"
    supabase_user_id: Optional[str] = None
    pricing_type: Optional[str] = "hourly"
    per_job_rate: Optional[int] = 0
    fixed_rate: Optional[int] = 0
    rate: Optional[int] = None

class RateValidateRequest(BaseModel):
    service_type_id: str
    rate: int
    area_name: str
    pricing_type: Optional[str] = "hourly"

@router.post("/providers/validate-rate")
async def validate_rate(req: RateValidateRequest):
    """Validate provider quoted rate against dynamic fair market price range."""
    from services.pricing_service import calculate_fair_price
    
    # Calculate fair range
    fair_range = calculate_fair_price(req.service_type_id, req.area_name, None, "normal")
    min_val = fair_range["min"]
    max_val = fair_range["max"]
    
    service_label = req.service_type_id.replace("_", " ").title()
    area_label = req.area_name or "your area"
    
    if req.rate < min_val or req.rate > max_val:
        if req.rate < min_val:
            direction = f"too low (minimum is Rs {min_val:,})"
        else:
            direction = f"too high (maximum is Rs {max_val:,})"
        return {
            "valid": False,
            "min": min_val,
            "max": max_val,
            "message": (
                f"Your rate of Rs {req.rate:,} PKR is {direction} for {service_label} in {area_label}. "
                f"The market value range is Rs {min_val:,} – Rs {max_val:,} PKR. "
                f"Please set a rate within this range to complete registration."
            ),
        }
    return {
        "valid": True,
        "min": min_val,
        "max": max_val,
        "message": f"Your rate of Rs {req.rate:,} is within the fair market range (Rs {min_val:,} – Rs {max_val:,}) for {service_label} in {area_label}.",
    }

@router.post("/providers/register")
async def register_provider(req: ProviderRegisterRequest):
    """Register a real provider into the Firebase database."""
    # Rate Validation
    from services.pricing_service import calculate_fair_price
    pricing_type = req.pricing_type or "hourly"
    rate = req.rate or req.hourly_rate
    if pricing_type == "fixed":
        rate = req.fixed_rate or rate
    elif pricing_type == "per_job":
        rate = req.per_job_rate or rate

    fair_range = calculate_fair_price(req.service_type_id, req.area_name, None, "normal")
    min_val = fair_range["min"]
    max_val = fair_range["max"]
    service_label = req.service_type_id.replace("_", " ").title()
    area_label = req.area_name or "your area"

    if rate < min_val or rate > max_val:
        direction = f"too low (minimum is Rs {min_val:,})" if rate < min_val else f"too high (maximum is Rs {max_val:,})"
        raise HTTPException(
            status_code=400,
            detail=(
                f"Your rate of Rs {rate:,} PKR is {direction} for {service_label} in {area_label}. "
                f"The market value range is Rs {min_val:,} – Rs {max_val:,} PKR. "
                f"Please set a rate within this range to complete registration."
            )
        )

    provider_id = req.supabase_user_id or f"PRV-{uuid.uuid4().hex[:8].upper()}"
    
    # Optional geocoding fallback if location coordinates are default
    lat = req.lat
    lng = req.lng
    if lat == 24.8607 and lng == 67.0099 and req.area_name:
        geo = await geocode_address(req.area_name)
        if geo:
            lat = geo["lat"]
            lng = geo["lng"]

    # Check if there is an existing provider document for this provider_id
    existing_rating = 5.0
    existing_reviews = 0
    existing_jobs = 0
    existing_cnic = False
    existing_exp = 1
    existing_gender = req.gender

    if req.supabase_user_id:
        existing_provider = await get_document("providers", req.supabase_user_id)
        if existing_provider:
            existing_rating = existing_provider.get("rating", 5.0)
            existing_reviews = existing_provider.get("total_reviews", 0)
            existing_jobs = existing_provider.get("jobs_completed", 0)
            existing_cnic = existing_provider.get("cnic_verified", False)
            existing_exp = existing_provider.get("experience_years", 1)
            existing_gender = req.gender or existing_provider.get("gender", "male")

    provider_data = {
        "id": provider_id,
        "name_en": req.name_en,
        "name_ur": req.name_en,
        "phone": req.phone,
        "service_type_id": req.service_type_id,
        "pricing_type": req.pricing_type or "hourly",
        "hourly_rate": req.hourly_rate,
        "fixed_rate": req.fixed_rate or 0,
        "per_job_rate": req.per_job_rate or 0,
        "rate": req.rate or req.hourly_rate,
        "area_name": req.area_name,
        "lat": lat,
        "lng": lng,
        "gender": existing_gender,
        "is_available": True,
        "rating": existing_rating,
        "total_reviews": existing_reviews,
        "jobs_completed": existing_jobs,
        "cnic_verified": existing_cnic,
        "experience_years": existing_exp,
        "supabase_user_id": req.supabase_user_id,
        "user_id": req.supabase_user_id,
    }
    
    await create_document("providers", provider_data, provider_id)
    
    # Sync location and details back to Supabase document under supabase_user_id if provided
    if req.supabase_user_id:
        await update_document("providers", req.supabase_user_id, {
            "lat": lat,
            "lng": lng,
            "backend_provider_id": provider_id,
            "location_updated_at": datetime.datetime.utcnow().isoformat()
        })
        
    return {"success": True, "provider_id": provider_id, "provider": provider_data}


@router.get("/providers/by_user/{user_id}")
async def get_provider_by_user_id(user_id: str):
    """Look up a provider record by their Supabase Auth user_id."""
    # Provider signup stores id = user_id (Supabase UUID)
    provider = await get_document("providers", user_id)
    if provider:
        return {"provider": provider}
    # Fallback: query by supabase_user_id or user_id field
    results = await query_collection("providers", filters=[("supabase_user_id", "eq", user_id)], limit=1)
    if results:
        return {"provider": results[0]}
    results = await query_collection("providers", filters=[("user_id", "eq", user_id)], limit=1)
    if results:
        return {"provider": results[0]}
    raise HTTPException(status_code=404, detail=f"No provider found for user_id={user_id}")


class ProviderUpdateRequest(BaseModel):
    name_en: Optional[str] = None
    phone: Optional[str] = None
    area_name: Optional[str] = None
    pricing_type: Optional[str] = None
    hourly_rate: Optional[int] = None
    fixed_rate: Optional[int] = None
    per_job_rate: Optional[int] = None
    rate: Optional[int] = None
    is_available: Optional[bool] = None

@router.put("/providers/{provider_id}/profile")
async def update_provider_profile(provider_id: str, req: ProviderUpdateRequest):
    """Update provider details in Firebase/Supabase."""
    provider = await get_document("providers", provider_id)
    if not provider:
        raise HTTPException(status_code=404, detail="Provider not found")
        
    # Rate Validation for update
    pricing_type = req.pricing_type or provider.get("pricing_type", "hourly")
    new_rate = None
    if req.rate is not None:
        new_rate = req.rate
    else:
        if pricing_type == "hourly" and req.hourly_rate is not None:
            new_rate = req.hourly_rate
        elif pricing_type == "fixed" and req.fixed_rate is not None:
            new_rate = req.fixed_rate
        elif pricing_type == "per_job" and req.per_job_rate is not None:
            new_rate = req.per_job_rate
            
    # If they are changing pricing_type but not providing rates, look up the existing rate for that pricing_type
    if new_rate is None and req.pricing_type is not None:
        if pricing_type == "hourly":
            new_rate = provider.get("hourly_rate")
        elif pricing_type == "fixed":
            new_rate = provider.get("fixed_rate")
        elif pricing_type == "per_job":
            new_rate = provider.get("per_job_rate")
            
    # If a rate check is needed, perform it
    if new_rate is not None:
        service_type_id = provider.get("service_type_id")
        area_name = req.area_name or provider.get("area_name")
        if service_type_id and area_name:
            from services.pricing_service import calculate_fair_price
            fair_range = calculate_fair_price(service_type_id, area_name, None, "normal")
            min_val = fair_range["min"]
            max_val = fair_range["max"]

            if new_rate < min_val or new_rate > max_val:
                raise HTTPException(
                    status_code=400,
                    detail=f"Rate {new_rate} PKR is out of the fair range. Kindly select a price between {min_val} and {max_val} PKR, as this is the market value for {service_type_id} in {area_name}."
                )

    update_data = {}
    if req.name_en is not None:
        update_data["name_en"] = req.name_en
        update_data["name_ur"] = req.name_en
    if req.phone is not None:
        update_data["phone"] = req.phone
    if req.area_name is not None:
        update_data["area_name"] = req.area_name
    if req.is_available is not None:
        update_data["is_available"] = req.is_available
        
    # Manage rate / pricing types
    pricing_type = req.pricing_type or provider.get("pricing_type", "hourly")
    update_data["pricing_type"] = pricing_type
    
    if req.rate is not None:
        update_data["rate"] = req.rate
        if pricing_type == "hourly":
            update_data["hourly_rate"] = req.rate
        elif pricing_type == "fixed":
            update_data["fixed_rate"] = req.rate
        elif pricing_type == "per_job":
            update_data["per_job_rate"] = req.rate
    else:
        # Check individual updates
        if req.hourly_rate is not None:
            update_data["hourly_rate"] = req.hourly_rate
            if pricing_type == "hourly":
                update_data["rate"] = req.hourly_rate
        if req.fixed_rate is not None:
            update_data["fixed_rate"] = req.fixed_rate
            if pricing_type == "fixed":
                update_data["rate"] = req.fixed_rate
        if req.per_job_rate is not None:
            update_data["per_job_rate"] = req.per_job_rate
            if pricing_type == "per_job":
                update_data["rate"] = req.per_job_rate

    await update_document("providers", provider_id, update_data)
    return {"success": True, "message": "Profile updated successfully", "provider": {**provider, **update_data}}


@router.get("/providers/reverse_geocode")
async def get_reverse_geocode(lat: float, lng: float):
    """Resolve lat/lng to area name."""
    res = await reverse_geocode(lat, lng)
    return res



@router.get("/providers/nearby")
async def get_nearby_providers(
    lat: float = 24.8607,
    lng: float = 67.0099,
    service_type: str = None,
    radius_km: float = 15.0,
    limit: int = 20,
    womens_only: bool = False,
):

    """Find nearby providers with distance and ETA."""
    if service_type:
        gender_filter = "female" if womens_only else None
        providers = await get_providers_by_service(
            service_type=service_type,
            is_available=True,
            gender=gender_filter,
            limit_count=100,
        )
    else:
        filters = [("is_available", "==", True)]
        if womens_only:
            filters.append(("gender", "==", "female"))
        providers = await query_collection("providers", filters=filters, limit=100)

    # Calculate distances and filter by radius
    results = []
    seen_ids = set()
    for provider in providers:
        p_id = provider.get("id")
        if p_id in seen_ids:
            continue
        dist = haversine_km(lat, lng, provider.get("lat", 0), provider.get("lng", 0))
        if dist <= radius_km:
            eta = estimate_eta_minutes(dist)
            trust = calculate_trust_score(provider)
            seen_ids.add(p_id)
            # Guarantee all pricing fields — old docs may be missing some
            p_type    = provider.get("pricing_type") or "hourly"
            h_rate    = int(provider.get("hourly_rate")  or 0)
            pj_rate   = int(provider.get("per_job_rate") or 0)
            fx_rate   = int(provider.get("fixed_rate")   or 0)
            raw_rate  = int(provider.get("rate")         or 0)
            if p_type == "per_job":
                eff_rate = pj_rate or raw_rate or h_rate
            elif p_type == "fixed":
                eff_rate = fx_rate or raw_rate or h_rate
            else:
                eff_rate = h_rate or raw_rate
            results.append({
                "id": provider.get("id"),
                "name": provider.get("name_en") or provider.get("name", "Provider"),
                "name_en": provider.get("name_en"),
                "name_ur": provider.get("name_ur"),
                "service_type_id": provider.get("service_type_id"),
                "rating": provider.get("rating", 5.0),
                "total_reviews": provider.get("total_reviews", 0),
                "pricing_type": p_type,
                "hourly_rate": h_rate,
                "fixed_rate": fx_rate,
                "per_job_rate": pj_rate,
                "rate": eff_rate,
                "distance_km": round(dist, 2),
                "eta_minutes": eta,
                "area_name": provider.get("area_name"),
                "trust_score": trust["trust_score"],
                "trust_badge": trust["badge"],
                "gender": provider.get("gender"),
                "experience_years": provider.get("experience_years"),
                "is_emergency_available": provider.get("is_emergency_available"),
                "cnic_verified": provider.get("cnic_verified"),
                "is_available": provider.get("is_available", True),
            })

    results.sort(key=lambda x: x["distance_km"])
    results = results[:limit]

    return {
        "providers": results,
        "total": len(results),
        "search_params": {
            "lat": lat, "lng": lng,
            "radius_km": radius_km,
            "service_type": service_type,
        },
    }


@router.get("/providers/search")
async def search_providers(
    query: str = "",
    area: str = "",
    service_type: str = "",
    min_rating: float = 0,
    max_price: int = 99999,
    limit: int = 20,
    include_offline: bool = True,
):
    """Search providers by text, area, or service type."""
    filters = []
    if not include_offline:
        filters.append(("is_available", "==", True))
    if service_type:
        filters.append(("service_type_id", "==", service_type))

    providers = await query_collection("providers", filters=filters, limit=100)

    # Apply additional filters — deduplicate by ID only, not by name/phone
    results = []
    seen_ids = set()
    for p in providers:
        p_id = p.get("id")
        if p_id in seen_ids:
            continue
        if min_rating and p.get("rating", 0) < min_rating:
            continue
        # Use the effective rate based on pricing_type for price filtering
        pt = p.get("pricing_type", "hourly")
        if pt == "per_job":
            effective_rate = p.get("per_job_rate") or p.get("rate") or p.get("hourly_rate") or 0
        elif pt == "fixed":
            effective_rate = p.get("fixed_rate") or p.get("rate") or p.get("hourly_rate") or 0
        else:
            effective_rate = p.get("hourly_rate") or p.get("rate") or 0
        if max_price and effective_rate > max_price:
            continue
        if area:
            if area.lower() not in p.get("area_name", "").lower():
                continue
        if query:
            searchable = f"{p.get('name_en', '')} {p.get('name', '')} {p.get('bio_en', '')} {p.get('area_name', '')}".lower()
            if query.lower() not in searchable:
                continue
        seen_ids.add(p_id)
        # Build explicit result with guaranteed pricing fields (old docs may be missing them)
        pricing_type = p.get("pricing_type") or "hourly"
        hourly_rate  = int(p.get("hourly_rate") or 0)
        per_job_rate = int(p.get("per_job_rate") or 0)
        fixed_rate   = int(p.get("fixed_rate") or 0)
        # Effective rate for the active pricing model
        if pricing_type == "per_job":
            effective_rate = per_job_rate or int(p.get("rate") or 0) or hourly_rate
        elif pricing_type == "fixed":
            effective_rate = fixed_rate or int(p.get("rate") or 0) or hourly_rate
        else:
            effective_rate = hourly_rate or int(p.get("rate") or 0)
        results.append({
            **p,  # keep all existing fields (bio, trust_score, etc.)
            # Normalise the name field — Flutter stores name_en, web may use name
            "name": p.get("name_en") or p.get("name", "Provider"),
            # Override/guarantee pricing fields
            "pricing_type": pricing_type,
            "hourly_rate": hourly_rate,
            "per_job_rate": per_job_rate,
            "fixed_rate": fixed_rate,
            "rate": effective_rate,
        })

    return {"providers": results[:limit], "total": len(results)}


@router.get("/providers/{provider_id}")
async def get_provider(provider_id: str):
    """Get full provider profile with trust breakdown."""
    provider = await get_document("providers", provider_id)
    if not provider:
        raise HTTPException(status_code=404, detail="Provider not found")

    trust = calculate_trust_score(provider)
    return {
        **provider,
        "trust_details": trust,
    }


@router.get("/service-types")
async def list_service_types():
    """List all available service types."""
    types = await query_collection("serviceTypes")
    return {"service_types": types, "total": len(types)}


class LocationUpdateRequest(BaseModel):
    lat: float
    lng: float
    accuracy: float = 0.0


@router.put("/providers/{provider_id}/location")
async def update_provider_location(provider_id: str, req: LocationUpdateRequest):
    """
    Real-time location update for a provider (called from provider's Flutter app).
    Updates lat/lng in Firebase so nearby searches reflect current position.
    """
    from services.firebase_service import update_document
    try:
        await update_document("providers", provider_id, {
            "lat": req.lat,
            "lng": req.lng,
            "location_updated_at": __import__("datetime").datetime.utcnow().isoformat(),
            "is_available": True,
        })
        return {"success": True, "message": "Location updated", "lat": req.lat, "lng": req.lng}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update location: {e}")


@router.get("/providers/{provider_id}/location")
async def get_provider_location(provider_id: str):
    """Get the current live location of a specific provider."""
    provider = await get_document("providers", provider_id)
    if not provider:
        raise HTTPException(status_code=404, detail="Provider not found")
    return {
        "provider_id": provider_id,
        "lat": provider.get("lat"),
        "lng": provider.get("lng"),
        "location_updated_at": provider.get("location_updated_at"),
        "is_available": provider.get("is_available", False),
    }


@router.post("/reviews")
async def create_review(req: ReviewCreate):
    """
    Create a new review for a provider and update their average rating and total_reviews.
    """
    import uuid
    import datetime
    from services.firebase_service import create_document, get_document, update_document, query_collection
    from services.trust_service import calculate_trust_score
    
    # 1. Verify the booking exists
    booking = await get_document("bookings", req.booking_id)
    if not booking:
        results = await query_collection("bookings", filters=[("id", "eq", req.booking_id)])
        if results:
            booking = results[0]
            
    if not booking:
        raise HTTPException(status_code=404, detail=f"Booking not found (ID: {req.booking_id})")
    
    # 2. Verify the provider exists
    provider = await get_document("providers", req.provider_id)
    if not provider:
        results = await query_collection("providers", filters=[("id", "eq", req.provider_id)])
        if results:
            provider = results[0]
            
    if not provider:
        raise HTTPException(status_code=404, detail=f"Provider not found (ID: {req.provider_id})")
        
    citizen_id = booking.get("citizen_id", "anonymous")
    
    # 3. Analyze sentiment of the review_text (Simple sentiment analysis)
    sentiment_score = 0.5
    sentiment_label = "neutral"
    text_lower = req.review_text.lower()
    positive_words = ["good", "excellent", "great", "best", "very happy", "nice", "professional", "amazing", "fast", "polite", "zabar-dast", "shukriya", "bohot acha", "khush"]
    negative_words = ["bad", "poor", "slow", "rude", "worst", "unprofessional", "expensive", "hate", "scam", "kharab", "ganda", "der"]
    
    pos_count = sum(1 for w in positive_words if w in text_lower)
    neg_count = sum(1 for w in negative_words if w in text_lower)
    
    if pos_count > neg_count:
        sentiment_score = 0.8
        sentiment_label = "positive" if pos_count < 3 else "very_positive"
    elif neg_count > pos_count:
        sentiment_score = 0.2
        sentiment_label = "negative" if neg_count < 3 else "very_negative"
        
    # 4. Save review document
    review_id = f"REV-{uuid.uuid4().hex[:8].upper()}"
    review_data = {
        "id": review_id,
        "provider_id": req.provider_id,
        "booking_id": req.booking_id,
        "citizen_id": citizen_id,
        "citizen_name": booking.get("user_name", "Anonymous"),
        "rating": float(req.rating),
        "review_text": req.review_text,
        "sentiment_score": sentiment_score,
        "sentiment_label": sentiment_label,
        "is_fake_suspected": False,
        "created_at": datetime.datetime.utcnow().isoformat()
    }
    
    await create_document("reviews", review_data, review_id)
    
    # 5. Update provider rating & total_reviews
    old_rating = float(provider.get("rating", 4.0))
    total_reviews = int(provider.get("total_reviews", 0))
    
    new_total_reviews = total_reviews + 1
    new_rating = ((old_rating * total_reviews) + req.rating) / new_total_reviews
    new_rating = round(new_rating, 2)
    
    provider_update = {
        "total_reviews": new_total_reviews,
        "rating": new_rating,
    }
    
    # Recalculate trust score
    temp_provider = {**provider, **provider_update}
    trust = calculate_trust_score(temp_provider)
    provider_update["trust_score"] = trust["trust_score"]
    provider_update["trust_badge"] = trust["badge"]
    
    await update_document("providers", req.provider_id, provider_update)
    
    # 6. Update booking status or flag that it's reviewed
    await update_document("bookings", req.booking_id, {"review_submitted": True, "rating": req.rating, "review_text": req.review_text})
    
    return {
        "success": True, 
        "review_id": review_id, 
        "new_rating": new_rating, 
        "total_reviews": new_total_reviews
    }


@router.get("/providers/{provider_id}/reviews")
async def get_provider_reviews(provider_id: str):
    """
    Get all reviews/comments for a specific provider.
    """
    from services.firebase_service import query_collection
    reviews = await query_collection("reviews", filters=[("provider_id", "eq", provider_id)], order_by="-created_at")
    return {"reviews": reviews, "total": len(reviews)}


