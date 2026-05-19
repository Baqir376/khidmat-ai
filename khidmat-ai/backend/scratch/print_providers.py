import asyncio
from services.firebase_service import get_all_documents

async def main():
    providers = await get_all_documents("providers")
    for p in providers:
        print(f"ID: {p.get('id')} | Name: {p.get('name_en')} | Gender: {p.get('gender')}")

if __name__ == '__main__':
    asyncio.run(main())
