import asyncio
from services.firebase_service import get_all_documents, update_document

async def main():
    print("Fetching all providers from Supabase...")
    providers = await get_all_documents("providers")
    print(f"Found {len(providers)} providers.")
    
    updated_count = 0
    for p in providers:
        p_id = p.get("id") or p.get("doc_id")
        if not p_id:
            continue
        
        # Only update if gender is not male
        if p.get("gender") != "male":
            print(f"Updating provider '{p.get('name_en')}' ({p_id}) gender from '{p.get('gender')}' to 'male'...")
            success = await update_document("providers", p_id, {"gender": "male"})
            if success:
                updated_count += 1
            else:
                print(f"Failed to update provider {p_id}")
    
    print(f"Completed! Updated {updated_count} providers to gender: male.")

if __name__ == '__main__':
    asyncio.run(main())
