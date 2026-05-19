import asyncio
import sys
import os

# Adjust sys.path to backend directory
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from services.firebase_service import query_collection

async def main():
    providers = await query_collection("providers")
    print(f"Total providers found: {len(providers)}")
    for i, p in enumerate(providers):
        print(f"\nProvider #{i+1}:")
        print(f"  ID: {p.get('id')}")
        print(f"  Name: {p.get('name_en')}")
        print(f"  Service Type ID: {p.get('service_type_id')}")
        print(f"  Is Available: {p.get('is_available')}")
        print(f"  Lat/Lng: {p.get('lat')}, {p.get('lng')}")
        print(f"  Gender: {p.get('gender')}")
        print(f"  Coverage Radius: {p.get('coverage_radius_km')}")

if __name__ == "__main__":
    asyncio.run(main())
