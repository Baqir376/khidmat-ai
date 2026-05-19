import asyncio
import json
from services.firebase_service import query_collection

async def main():
    providers = await query_collection("providers")
    with open("providers_dump.json", "w", encoding="utf-8") as f:
        json.dump(providers, f, indent=2, ensure_ascii=False)
    print("Dumped providers successfully!")

if __name__ == '__main__':
    asyncio.run(main())
