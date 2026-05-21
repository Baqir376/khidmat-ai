"""
KaamSaaz — Trust Scoring Service
Composite trust score from 5 factors: reviews, completion, response time,
verification, and experience. Used by MatchingAgent for provider ranking.
"""


WEIGHTS = {
    "review_score": 0.30,
    "completion_score": 0.25,
    "response_score": 0.20,
    "verification_score": 0.15,
    "experience_score": 0.10,
}


def calculate_trust_score(provider: dict) -> dict:
    """
    Calculate composite trust score (0-100) for a provider.
    Returns score, badge, breakdown, and reasoning.
    """
    # 1. Review Score (rating * review volume factor)
    rating = provider.get("rating", 3.0)
    total_reviews = provider.get("total_reviews", 0)
    volume_factor = min(1.0, total_reviews / 50)  # Full weight at 50+ reviews
    review_score = (rating / 5.0) * 100 * volume_factor

    # 2. Completion Score (inverse of cancellation rate)
    cancellation_rate = provider.get("cancellation_rate", 0.1)
    completion_score = (1.0 - cancellation_rate) * 100

    # 3. Response Time Score (faster is better, 5 min = perfect, 60 min = 0)
    avg_response = provider.get("avg_response_time_minutes", 30)
    response_score = max(0, min(100, (60 - avg_response) / 55 * 100))

    # 4. Verification Score (binary checks)
    cnic_verified = 50 if provider.get("cnic_verified", False) else 0
    insurance = 25 if provider.get("insurance_active", False) else 0
    blockchain = 25 if provider.get("blockchain_address") else 0
    verification_score = cnic_verified + insurance + blockchain

    # 5. Experience Score (capped at 10 years for full marks)
    years = provider.get("experience_years", 1)
    experience_score = min(100, (years / 10) * 100)

    # Composite score
    composite = (
        WEIGHTS["review_score"] * review_score
        + WEIGHTS["completion_score"] * completion_score
        + WEIGHTS["response_score"] * response_score
        + WEIGHTS["verification_score"] * verification_score
        + WEIGHTS["experience_score"] * experience_score
    )
    composite = round(composite, 1)

    # Badge
    if composite >= 90:
        badge = "Elite"
    elif composite >= 75:
        badge = "Gold"
    elif composite >= 55:
        badge = "Silver"
    else:
        badge = "Bronze"

    # Build reasoning text
    breakdown = {
        "review_score": round(review_score, 1),
        "completion_score": round(completion_score, 1),
        "response_score": round(response_score, 1),
        "verification_score": round(verification_score, 1),
        "experience_score": round(experience_score, 1),
    }

    strengths = []
    weaknesses = []

    if review_score > 80:
        strengths.append(f"Strong reviews ({rating}⭐, {total_reviews} reviews)")
    elif review_score < 50:
        weaknesses.append(f"Limited reviews ({total_reviews} reviews)")

    if completion_score > 95:
        strengths.append(f"Excellent reliability ({round((1-cancellation_rate)*100)}% completion)")
    elif completion_score < 85:
        weaknesses.append(f"Higher cancellation rate ({round(cancellation_rate*100)}%)")

    if response_score > 80:
        strengths.append(f"Fast responder (~{round(avg_response)} min avg)")
    elif response_score < 40:
        weaknesses.append(f"Slow response time (~{round(avg_response)} min avg)")

    if verification_score >= 75:
        strengths.append("Fully verified (CNIC + Insurance)")
    elif verification_score < 50:
        weaknesses.append("Incomplete verification")

    reasoning = f"Trust Score: {composite}/100 ({badge}). "
    if strengths:
        reasoning += "Strengths: " + "; ".join(strengths) + ". "
    if weaknesses:
        reasoning += "Areas for improvement: " + "; ".join(weaknesses) + "."

    return {
        "trust_score": composite,
        "badge": badge,
        "breakdown": breakdown,
        "weights": WEIGHTS,
        "reasoning": reasoning,
        "strengths": strengths,
        "weaknesses": weaknesses,
    }
