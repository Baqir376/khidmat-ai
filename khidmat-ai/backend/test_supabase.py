import asyncio
import uuid
from services.firebase_service import create_document, get_providers_by_service

async def test():
    doc_id = str(uuid.uuid4())
    await create_document('providers', {'service_type_id': 'tutor', 'is_available': True, 'name_en': 'Test Tutor', 'id': doc_id}, doc_id)
    res = await get_providers_by_service('tutor')
    print(res)

asyncio.run(test())
