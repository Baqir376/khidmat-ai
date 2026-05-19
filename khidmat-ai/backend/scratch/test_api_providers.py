import requests

def main():
    try:
        res = requests.get("http://localhost:8000/api/providers/search?limit=50")
        print("Status:", res.status_code)
        data = res.json()
        providers = data.get("providers", [])
        print(f"Total providers returned: {len(providers)}")
        for p in providers:
            print(f"Name: {p.get('name')}")
            print(f"  ID: {p.get('id')}")
            print(f"  Jobs Completed: {p.get('jobs_completed')}")
            print(f"  Rating: {p.get('rating')}")
            print(f"  is_available: {p.get('is_available')}")
            print("-" * 40)
    except Exception as e:
        print("Error calling API:", e)

if __name__ == "__main__":
    main()
