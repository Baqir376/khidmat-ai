import os
import sys
import json
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services.gemini_service import _mock_response

def test_analytics():
    # Dynamic inputs simulating a loaded dashboard environment
    providers_ctx = [
        {"id": "p1", "name": "Babar Azam", "specialty": "plumber", "rating": 4.8, "jobs_completed": 10, "total_income_pkr": 15000, "is_available": True},
        {"id": "p2", "name": "Shaheen Afridi", "specialty": "electrician", "rating": 4.9, "jobs_completed": 15, "total_income_pkr": 25000, "is_available": True},
        {"id": "p3", "name": "Sajid Khan", "specialty": "plumber", "rating": 4.2, "jobs_completed": 2, "total_income_pkr": 3000, "is_available": False},
        {"id": "p4", "name": "Haris Rauf", "specialty": "carpenter", "rating": 4.5, "jobs_completed": 5, "total_income_pkr": 8000, "is_available": False},
        {"id": "p5", "name": "Naseem Shah", "specialty": "electrician", "rating": 4.7, "jobs_completed": 8, "total_income_pkr": 12000, "is_available": True}
    ]

    bookings_ctx = [
        {"id": "b1", "customer": "Malik", "provider": "Babar Azam", "status": "COMPLETED", "price_pkr": 1500},
        {"id": "b2", "customer": "Imran", "provider": "Shaheen Afridi", "status": "COMPLETED", "price_pkr": 2500},
        {"id": "b3", "customer": "Khan", "provider": "Naseem Shah", "status": "COMPLETED", "price_pkr": 1200},
        {"id": "b4", "customer": "Rizwan", "provider": "Haris Rauf", "status": "COMPLETED", "price_pkr": 1600},
        {"id": "b5", "customer": "Babar", "provider": "Sajid Khan", "status": "PENDING", "price_pkr": 1000},
        {"id": "b6", "customer": "Shadab", "provider": "Babar Azam", "status": "CANCELLED", "price_pkr": 1500}
    ]

    # Test cases for all edge-case scenarios
    queries = [
        # Lowest income
        ("mujhe ye batao sab se kam income kis ki hai", "kam income"),
        # Highest income
        ("sab se zyada income kis ki hai", "highest income"),
        # Average income
        ("what is the average earning of providers", "average earning"),
        # Average rating
        ("active providers ki average rating kya hai", "average rating"),
        # Status breakdown
        ("bookings breakdown status details", "status breakdown"),
        # Availability online status
        ("kon free hai is waqt online providers list", "availability online"),
        # Specialty count
        ("platform par kaunsi specialty ke zyada providers hain", "specialty count"),
        # Average jobs
        ("average jobs completed dynamic value", "average jobs"),
        # Specific provider details
        ("babar azam ke details aur ratings kya hain", "specific provider Babar Azam"),
        # Success Rate
        ("what is the success rate of booking matches", "success rate")
    ]

    for user_query, description in queries:
        system_instruction = f"""You are the Khidmat Copilot.
=== LIVE DASHBOARD DATA CONTEXT ===
1. Aggregate Statistics:
   - Total Bookings: 6
   - Active Providers: 5
   - Gross Merchandise Value (GMV): PKR 6,800
   - Successful/Confirmed Bookings Count: 4

2. Active Providers Registry (Earnings & Performance):
{json.dumps(providers_ctx, indent=2)}

3. Bookings Ledger:
{json.dumps(bookings_ctx, indent=2)}

4. Recent Agent Reasoning Traces:
[]
"""
        prompt = f"{system_instruction}\n\nAdministrator: {user_query}"
        response = _mock_response(prompt)
        print(f"\n--- TEST: {description} ---")
        print(f"Query: '{user_query}'")
        print(f"Response:\n{response}")

if __name__ == "__main__":
    test_analytics()
