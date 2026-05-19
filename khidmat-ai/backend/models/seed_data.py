"""
Khidmat AI — Seed Data
200 realistic Pakistani providers across 10 service types and 20 Karachi areas.
All names, areas, pricing, and bios are Pakistan-specific. No placeholders.
"""
import random
import hashlib
import uuid
from datetime import datetime

# ============================================================
# KARACHI AREAS (20 real areas with accurate coordinates)
# ============================================================

KARACHI_AREAS = [
    {"name": "DHA Phase 5", "lat": 24.8134, "lng": 67.0323},
    {"name": "Clifton Block 4", "lat": 24.8138, "lng": 67.0255},
    {"name": "Gulshan-e-Iqbal Block 13", "lat": 24.9214, "lng": 67.1013},
    {"name": "PECHS Block 2", "lat": 24.8720, "lng": 67.0588},
    {"name": "North Nazimabad Block H", "lat": 24.9540, "lng": 67.0352},
    {"name": "Nazimabad No. 3", "lat": 24.9194, "lng": 67.0186},
    {"name": "Korangi Industrial", "lat": 24.8295, "lng": 67.1309},
    {"name": "Malir Halt", "lat": 24.8946, "lng": 67.2000},
    {"name": "Landhi Colony", "lat": 24.8484, "lng": 67.1785},
    {"name": "Orangi Town Sector 11", "lat": 24.9566, "lng": 66.9980},
    {"name": "Liaquatabad No. 10", "lat": 24.9050, "lng": 67.0532},
    {"name": "Federal B Area Block 4", "lat": 24.9299, "lng": 67.0686},
    {"name": "Saddar Cantt", "lat": 24.8607, "lng": 67.0099},
    {"name": "Garden East", "lat": 24.8720, "lng": 67.0295},
    {"name": "Lyari Town", "lat": 24.8574, "lng": 66.9948},
    {"name": "Baldia Town", "lat": 24.9085, "lng": 66.9737},
    {"name": "Surjani Town Sector 7A", "lat": 25.0012, "lng": 67.0400},
    {"name": "Shah Faisal Colony", "lat": 24.8826, "lng": 67.1351},
    {"name": "Bufferzone Sector 15A", "lat": 24.9681, "lng": 67.0618},
    {"name": "Gulistan-e-Jauhar Block 14", "lat": 24.9263, "lng": 67.1354},
]

# ============================================================
# NAMES (Pakistani male and female names)
# ============================================================

MALE_FIRST_NAMES = [
    "Muhammad", "Ahmed", "Bilal", "Usman", "Tariq", "Asif", "Khalid",
    "Imran", "Farhan", "Zubair", "Abdul", "Shahid", "Naveed", "Rizwan",
    "Hamza", "Waseem", "Saad", "Danish", "Faisal", "Kamran", "Aamir",
    "Sohail", "Babar", "Waqar", "Junaid", "Adnan", "Sajid", "Tahir",
    "Rashid", "Nasir",
]

FEMALE_FIRST_NAMES = [
    "Fatima", "Ayesha", "Sana", "Hira", "Zainab", "Nadia", "Bushra",
    "Saima", "Rabia", "Mehwish", "Uzma", "Amina", "Kiran", "Sobia",
    "Farzana",
]

LAST_NAMES = [
    "Ali", "Khan", "Ahmed", "Sheikh", "Qureshi", "Siddiqui", "Mirza",
    "Butt", "Malik", "Chaudhry", "Iqbal", "Hussain", "Ansari", "Abbasi",
    "Baig", "Raza", "Nawaz", "Gillani", "Bhutto", "Niazi",
]

# ============================================================
# SERVICE TYPES (10 categories with accurate PKR pricing)
# ============================================================

SERVICE_TYPES = [
    {
        "id": "electrician",
        "name_en": "Electrician",
        "name_ur": "الیکٹریشن",
        "name_roman_ur": "Electrician",
        "name_sd": "بجلي ڪار",
        "icon": "⚡",
        "base_rate_min": 800,
        "base_rate_max": 2500,
        "peak_multiplier": 1.3,
        "category": "electrical",
    },
    {
        "id": "plumber",
        "name_en": "Plumber",
        "name_ur": "پلمبر",
        "name_roman_ur": "Plumber",
        "name_sd": "نلڪاري",
        "icon": "🔧",
        "base_rate_min": 600,
        "base_rate_max": 2000,
        "peak_multiplier": 1.4,
        "category": "plumbing",
    },
    {
        "id": "ac_technician",
        "name_en": "AC Technician",
        "name_ur": "اے سی ٹیکنیشن",
        "name_roman_ur": "AC Technician",
        "name_sd": "اي سي ٽيڪنيشن",
        "icon": "❄️",
        "base_rate_min": 1200,
        "base_rate_max": 3500,
        "peak_multiplier": 1.2,
        "category": "hvac",
    },
    {
        "id": "carpenter",
        "name_en": "Carpenter",
        "name_ur": "بڑھئی",
        "name_roman_ur": "Badhai",
        "name_sd": "ڪاٺار",
        "icon": "🪚",
        "base_rate_min": 1000,
        "base_rate_max": 3000,
        "peak_multiplier": 1.1,
        "category": "construction",
    },
    {
        "id": "painter",
        "name_en": "Painter",
        "name_ur": "پینٹر",
        "name_roman_ur": "Painter",
        "name_sd": "رنگريز",
        "icon": "🎨",
        "base_rate_min": 800,
        "base_rate_max": 2500,
        "peak_multiplier": 1.0,
        "category": "construction",
    },
    {
        "id": "tutor",
        "name_en": "Tutor",
        "name_ur": "ٹیوٹر",
        "name_roman_ur": "Tutor",
        "name_sd": "استاد",
        "icon": "📚",
        "base_rate_min": 500,
        "base_rate_max": 2000,
        "peak_multiplier": 1.1,
        "category": "education",
    },
    {
        "id": "beautician",
        "name_en": "Beautician",
        "name_ur": "بیوٹیشن",
        "name_roman_ur": "Beautician",
        "name_sd": "سنگهار وارو",
        "icon": "💅",
        "base_rate_min": 800,
        "base_rate_max": 3000,
        "peak_multiplier": 1.2,
        "category": "beauty",
    },
    {
        "id": "generator",
        "name_en": "Generator Repair",
        "name_ur": "جنریٹر مرمت",
        "name_roman_ur": "Generator wala",
        "name_sd": "جنريٽر مرمت",
        "icon": "⚙️",
        "base_rate_min": 1500,
        "base_rate_max": 4000,
        "peak_multiplier": 1.5,
        "category": "electrical",
    },
    {
        "id": "welder",
        "name_en": "Welder",
        "name_ur": "ویلڈر",
        "name_roman_ur": "Welder",
        "name_sd": "ويلڊر",
        "icon": "🔥",
        "base_rate_min": 1000,
        "base_rate_max": 3000,
        "peak_multiplier": 1.1,
        "category": "construction",
    },
    {
        "id": "tiler",
        "name_en": "Tiler",
        "name_ur": "ٹائلر",
        "name_roman_ur": "Tiles wala",
        "name_sd": "ٽائيلر",
        "icon": "🏗️",
        "base_rate_min": 1200,
        "base_rate_max": 3500,
        "peak_multiplier": 1.1,
        "category": "construction",
    },
]

# ============================================================
# BIO TEMPLATES (for generating realistic bios)
# ============================================================

BIO_TEMPLATES_EN = {
    "electrician": [
        "{years} years experience in residential and commercial wiring, circuit breaker installation, and fan repair.",
        "Specialist in split AC wiring, LED panel installation, and emergency power restoration. {years} years in the field.",
        "Certified electrician handling UPS installation, generator wiring, and smart home systems. {years} years experience.",
    ],
    "plumber": [
        "{years} years of pipe fitting, drain cleaning, and bathroom renovation in Karachi.",
        "Expert in water tank repair, motor pump installation, and sewage line clearing. {years} years experience.",
        "Specialist in geyser repair, water filtration setup, and leak detection. {years} years of service.",
    ],
    "ac_technician": [
        "{years} years servicing split, window, and cassette AC units. Gas charging and compressor repair specialist.",
        "Certified in Gree, Haier, and Orient AC servicing. PCB repair and deep cleaning expert. {years} years experience.",
        "AC installation, shifting, and annual maintenance. {years} years handling all major brands.",
    ],
    "carpenter": [
        "{years} years crafting custom furniture, kitchen cabinets, and door frames.",
        "Specialist in wardrobe design, wood polishing, and ceiling work. {years} years experience.",
    ],
    "painter": [
        "{years} years in interior and exterior painting, texture finish, and wall putty work.",
        "Expert in Nippon and Berger paints application, damp-proofing, and decorative walls. {years} years.",
    ],
    "tutor": [
        "{years} years teaching O-Level Mathematics and Physics. Home tuition in Karachi.",
        "Experienced in Matric and Inter board exams preparation. {years} years of teaching.",
    ],
    "beautician": [
        "{years} years providing bridal makeup, threading, facials, and mehndi services at home.",
        "Specialist in party makeup, hair styling, and skincare treatments. {years} years experience.",
    ],
    "generator": [
        "{years} years repairing Honda, Jasco, and local generators. Oil change and winding repair.",
    ],
    "welder": [
        "{years} years in gate fabrication, grill work, and structural welding.",
    ],
    "tiler": [
        "{years} years laying floor tiles, wall tiles, and marble work in homes and offices.",
    ],
}

BIO_TEMPLATES_UR = {
    "electrician": "الیکٹریشن کا {years} سال کا تجربہ — وائرنگ، فین، اے سی، اور ایمرجنسی پاور",
    "plumber": "پلمبنگ کا {years} سال کا تجربہ — پائپ، نلکا، ڈرین، اور باتھ روم",
    "ac_technician": "اے سی ٹیکنیشن — {years} سال — گیس چارج، کمپریسر، اور سروسنگ",
    "carpenter": "بڑھئی — {years} سال — فرنیچر، الماری، اور دروازے",
    "painter": "پینٹنگ — {years} سال — اندرونی، بیرونی، اور ٹیکسچر",
    "tutor": "ٹیوشن — {years} سال — میتھ، فزکس، اور انگلش",
    "beautician": "بیوٹی سروسز — {years} سال — میک اپ، تھریڈنگ، اور مہندی",
    "generator": "جنریٹر مرمت — {years} سال",
    "welder": "ویلڈنگ — {years} سال — گیٹ، گرل، اور فیبریکیشن",
    "tiler": "ٹائلز — {years} سال — فلور اور وال ٹائلز",
}

# ============================================================
# TRUST BADGE LOGIC
# ============================================================

def calculate_trust_badge(trust_score: float) -> str:
    if trust_score >= 90:
        return "Elite"
    elif trust_score >= 75:
        return "Gold"
    elif trust_score >= 55:
        return "Silver"
    return "Bronze"


# ============================================================
# GENERATE 200 PROVIDERS
# ============================================================

def generate_providers(count: int = 200) -> list[dict]:
    """Generate realistic provider data for seeding Firestore."""
    providers = []
    random.seed(42)  # Reproducible for demos

    # Female-only service types
    female_services = {"beautician", "tutor"}
    # Male-dominant service types
    male_services = {"electrician", "plumber", "ac_technician", "carpenter",
                     "painter", "generator", "welder", "tiler"}

    for i in range(count):
        service = random.choice(SERVICE_TYPES)
        service_id = service["id"]
        area = random.choice(KARACHI_AREAS)

        # Determine gender based on service type
        if service_id in female_services and random.random() < 0.7:
            gender = "female"
            first_name = random.choice(FEMALE_FIRST_NAMES)
        elif service_id in male_services:
            gender = "male"
            first_name = random.choice(MALE_FIRST_NAMES)
        else:
            gender = random.choice(["male", "female"])
            first_name = (
                random.choice(FEMALE_FIRST_NAMES) if gender == "female"
                else random.choice(MALE_FIRST_NAMES)
            )

        last_name = random.choice(LAST_NAMES)
        full_name = f"{first_name} {last_name}"
        experience = random.randint(2, 20)

        # Generate bio
        bio_templates = BIO_TEMPLATES_EN.get(service_id, ["{years} years of professional experience."])
        bio_en = random.choice(bio_templates).format(years=experience)
        bio_ur_template = BIO_TEMPLATES_UR.get(service_id, "{years} سال کا تجربہ")
        bio_ur = bio_ur_template.format(years=experience)

        # Pricing within service range
        rate_spread = service["base_rate_max"] - service["base_rate_min"]
        hourly_rate = service["base_rate_min"] + random.randint(0, rate_spread)

        # Trust and ratings (weighted toward good providers)
        trust_score = round(random.gauss(72, 15), 1)
        trust_score = max(30, min(100, trust_score))
        rating = round(random.gauss(4.2, 0.5), 1)
        rating = max(2.5, min(5.0, rating))
        total_jobs = random.randint(5, 500)
        total_reviews = random.randint(3, int(total_jobs * 0.7))
        cancellation_rate = round(random.uniform(0, 0.15), 2)
        avg_response = round(random.uniform(3, 45), 1)

        # Add slight position variation within area
        lat = area["lat"] + random.uniform(-0.008, 0.008)
        lng = area["lng"] + random.uniform(-0.008, 0.008)

        # CNIC hash (mock — deterministic from name)
        cnic_raw = f"35{random.randint(100, 999)}-{random.randint(1000000, 9999999)}-{random.randint(1, 9)}"
        cnic_hash = hashlib.sha256(cnic_raw.encode()).hexdigest()

        provider = {
            "id": str(uuid.uuid4())[:12],
            "user_id": f"user_{i:04d}",
            "service_type_id": service_id,
            "name_en": full_name,
            "name_ur": full_name,  # Using transliterated name for demo
            "bio_en": bio_en,
            "bio_ur": bio_ur,
            "experience_years": experience,
            "cnic_hash": cnic_hash,
            "cnic_verified": random.random() > 0.25,  # 75% verified
            "gender": gender,
            "lat": round(lat, 6),
            "lng": round(lng, 6),
            "area_name": area["name"],
            "city": "Karachi",
            "coverage_radius_km": round(random.uniform(5, 15), 1),
            "hourly_rate": hourly_rate,
            "is_available": random.random() > 0.2,  # 80% available
            "is_emergency_available": random.random() > 0.6,  # 40% emergency
            "trust_score": trust_score,
            "trust_badge": calculate_trust_badge(trust_score),
            "total_jobs": total_jobs,
            "cancellation_rate": cancellation_rate,
            "avg_response_time_minutes": avg_response,
            "rating": rating,
            "total_reviews": total_reviews,
            "portfolio_urls": [],
            "instagram_handle": None,
            "blockchain_address": None,
            "insurance_active": random.random() > 0.7,
            "welfare_score": round(random.uniform(30, 90), 1),
            "skill_badges": [],
        }
        providers.append(provider)

    return providers


# Pre-generate for import
PROVIDERS = generate_providers(200)
