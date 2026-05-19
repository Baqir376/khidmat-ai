import requests
import json

def main():
    try:
        providers_res = requests.get("http://localhost:8000/api/providers/search?limit=100").json()
        bookings_res = requests.get("http://localhost:8000/api/bookings").json()
        
        providers = providers_res.get("providers", [])
        bookings = bookings_res.get("bookings", [])
        
        print(f"--- ACTIVE PROVIDERS ({len(providers)}) ---")
        for p in providers:
            print(f"ID: {p['id']}, Name: {p.get('name_en') or p.get('name')}, jobs_completed: {p.get('jobs_completed')}, rating: {p.get('rating')}, hourly_rate: {p.get('hourly_rate')}, rate: {p.get('rate')}")
            
        print(f"\n--- BOOKINGS ({len(bookings)}) ---")
        for b in bookings:
            print(f"ID: {b.get('id')}, Provider: {b.get('provider_id')}, Status: {b.get('status')}, Price: {b.get('final_price') or b.get('quoted_price') or b.get('price')}")
            
    except Exception as e:
        print(f"Error fetching data: {e}")

if __name__ == "__main__":
    main()
