import asyncio, sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from services.firebase_service import get_all_documents, query_collection

async def main():
    # Check total providers
    docs = await get_all_documents('providers')
    print(f'Total providers in DB: {len(docs)}')
    for p in docs:
        pid = p.get('id', 'N/A')
        name = p.get('name_en', 'N/A')
        stype = p.get('service_type_id', 'N/A')
        avail = p.get('is_available')
        phone = p.get('phone', 'N/A')
        print(f'  id={str(pid)[:36]} | name={name} | stype={stype} | is_available={avail} | phone={phone}')
    
    print('\n--- Electricians only ---')
    elec = await query_collection('providers', filters=[('service_type_id', '==', 'electrician')], limit=50)
    print(f'Electricians via ilike query: {len(elec)}')
    for p in elec:
        print(f'  {p.get("name_en")} | avail={p.get("is_available")} | id={str(p.get("id", ""))[:36]}')

asyncio.run(main())
