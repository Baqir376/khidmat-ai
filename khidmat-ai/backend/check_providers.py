import asyncio
from services.firebase_service import query_collection

async def main():
    providers = await query_collection("providers")
    print(f"Total providers found: {len(providers)}")
    
    services = {}
    for p in providers:
        st = p.get('service_type_id') or 'none'
        gender = p.get('gender') or 'none'
        lat = p.get('lat')
        lng = p.get('lng')
        
        # Calculate distance to Karachi center (24.8607, 67.0099)
        from services.maps_service import haversine_km
        dist = haversine_km(24.8607, 67.0099, lat, lng) if lat and lng else 9999
        in_range = dist <= 15.0
        
        if st not in services:
            services[st] = {'male': 0, 'female': 0, 'none': 0, 'male_in_range': 0, 'female_in_range': 0}
        services[st][gender] += 1
        if in_range:
            services[st][gender + '_in_range'] += 1

    print("\nService Type ID counts:")
    for st, counts in services.items():
        print(f"Service: {st}")
        print(f"  Male: {counts['male']} (in range: {counts['male_in_range']})")
        print(f"  Female: {counts['female']} (in range: {counts['female_in_range']})")
        print(f"  None: {counts['none']}")

if __name__ == '__main__':
    asyncio.run(main())
