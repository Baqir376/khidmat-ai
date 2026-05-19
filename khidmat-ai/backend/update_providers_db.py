import asyncio
from services.firebase_service import update_document

providers_data = [
    {
        "id": "0080eeac-f246-41ff-aade-655b42c02917",
        "name_en": "Muhammad Ali",
        "name_ur": "محمد علی",
        "rating": 4.8
    },
    {
        "id": "11f7e604-98df-4dc3-9435-5fa2ed558a44",
        "name_en": "Sajid Khan",
        "name_ur": "ساجد خان",
        "rating": 4.5
    },
    {
        "id": "e54dbafe-c2a3-459b-9279-2856b89d6329",
        "name_en": "Babar Azam",
        "name_ur": "بابر اعظم",
        "rating": 4.6
    },
    {
        "id": "f333d933-6630-4919-94fe-cf54cb655d97",
        "name_en": "Yasir Shah",
        "name_ur": "یاسر شاہ",
        "rating": 4.7
    }
]

async def main():
    print("Updating provider documents in Supabase...")
    for p in providers_data:
        success = await update_document("providers", p["id"], {
            "name_en": p["name_en"],
            "name_ur": p["name_ur"],
            "rating": p["rating"]
        })
        print(f"Updated {p['name_en']} ({p['id']}): {'SUCCESS' if success else 'FAILED'}")

if __name__ == '__main__':
    asyncio.run(main())
