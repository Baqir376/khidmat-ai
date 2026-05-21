"""
KaamSaaz — Supabase Database Service
Replaced Firebase/SQLite with a production-grade Supabase REST client.
Uses httpx for async, zero-dependency REST calls to Supabase.
"""
import uuid
import httpx
from datetime import datetime
from typing import Optional
from config import config

SUPABASE_URL = config.SUPABASE_URL
SUPABASE_KEY = config.SUPABASE_KEY

# Read headers — no Prefer header so GET queries work correctly
READ_HEADERS = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json",
}

# Write headers — include return=representation so we get inserted rows back
WRITE_HEADERS = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation",
}

# Legacy alias so other files importing HEADERS still work
HEADERS = READ_HEADERS

def _get_rest_url() -> str:
    # Remove trailing slash and append REST path
    url = SUPABASE_URL.rstrip('/')
    return f"{url}/rest/v1/documents"


_client = None

def get_supabase_client() -> httpx.AsyncClient:
    global _client
    if _client is None:
        limits = httpx.Limits(max_keepalive_connections=30, max_connections=150, keepalive_expiry=60.0)
        _client = httpx.AsyncClient(limits=limits, timeout=15.0)
    return _client


# ============================================================
# GENERIC CRUD OPERATIONS
# ============================================================

async def create_document(collection: str, data: dict, doc_id: Optional[str] = None) -> str:
    """Create a document in Supabase."""
    doc_id = doc_id or str(uuid.uuid4())[:12]
    data["id"] = doc_id
    data["created_at"] = datetime.utcnow().isoformat()
    data["updated_at"] = datetime.utcnow().isoformat()

    payload = {
        "collection": collection,
        "doc_id": doc_id,
        "data": data
    }

    client = get_supabase_client()
    # UPSERT: use resolution=merge-duplicates to safely handle duplicate doc_id.
    # NOTE: must use a dedicated dict so the Prefer header is not overwritten.
    upsert_headers = {
        **WRITE_HEADERS,
        "Prefer": "resolution=merge-duplicates,return=representation",
    }
    res = await client.post(_get_rest_url(), headers=upsert_headers, json=payload)
    if res.status_code >= 400:
        print(f"[Supabase] Upsert Error ({res.status_code}): {res.text[:300]}")

    return doc_id


async def get_document(collection: str, doc_id: str) -> Optional[dict]:
    """Get a single document by ID from Supabase."""
    client = get_supabase_client()
    res = await client.get(
        f"{_get_rest_url()}?collection=eq.{collection}&doc_id=eq.{doc_id}&select=data",
        headers=READ_HEADERS
    )
    if res.status_code == 200:
        docs = res.json()
        if len(docs) > 0:
            return docs[0].get("data")
    return None


async def update_document(collection: str, doc_id: str, data: dict) -> bool:
    """Update fields on an existing document in Supabase."""
    existing = await get_document(collection, doc_id)
    if not existing:
        return False
        
    existing.update(data)
    existing["updated_at"] = datetime.utcnow().isoformat()
    
    payload = {
        "data": existing
    }

    client = get_supabase_client()
    res = await client.patch(
        f"{_get_rest_url()}?collection=eq.{collection}&doc_id=eq.{doc_id}",
        headers={**WRITE_HEADERS, "Prefer": "return=minimal"},
        json=payload
    )
    if res.status_code >= 400:
        print(f"[Supabase] Update Error ({res.status_code}): {res.text[:200]}")
    return res.status_code < 400


async def delete_document(collection: str, doc_id: str) -> bool:
    """Delete a single document by ID from Supabase."""
    client = get_supabase_client()
    res = await client.delete(
        f"{_get_rest_url()}?collection=eq.{collection}&doc_id=eq.{doc_id}",
        headers={**WRITE_HEADERS, "Prefer": "return=minimal"}
    )
    if res.status_code >= 400:
        print(f"[Supabase] Delete Error ({res.status_code}): {res.text[:200]}")
    return res.status_code < 400


async def query_collection(
    collection: str,
    filters: Optional[list[tuple]] = None,
    order_by: Optional[str] = None,
    limit: Optional[int] = None,
) -> list[dict]:
    """Query documents with optional filters in Supabase using Postgres JSONB querying."""
    url = f"{_get_rest_url()}?collection=eq.{collection}&select=data"
    
    if filters:
        for field, op, value in filters:
            if isinstance(value, bool):
                value = str(value).lower()
            
            # Convert standard operators to Supabase PostgREST operators mapping against the JSONB "data" column
            if op == "==":
                # Use ilike for case-insensitive string matching
                url += f"&data->>{field}=ilike.{value}"
            elif op == "eq":  # Exact match — use for UUIDs, IDs
                url += f"&data->>{field}=eq.{value}"
            elif op == "ilike":
                url += f"&data->>{field}=ilike.*{value}*"
            elif op == ">=":
                url += f"&data->>{field}=gte.{value}"
            elif op == "<=":
                url += f"&data->>{field}=lte.{value}"
            elif op == "in":
                # value is a list, e.g., ['A', 'B'] -> (A,B)
                in_vals = ",".join([str(v) for v in value])
                url += f"&data->>{field}=in.({in_vals})"

    if limit:
        url += f"&limit={limit}"
        
    client = get_supabase_client()
    try:
        print(f"[Supabase] Query URL: {url}")
        response = await client.get(url, headers=READ_HEADERS)
        if response.status_code != 200:
            print(f"[Supabase] Query Error ({response.status_code}): {response.text[:300]}")
            return []

        data = response.json()
        print(f"[Supabase] Query returned {len(data)} rows")

        # Post-process order_by locally since JSONB order_by in PostgREST is complex via URL
        results = [row["data"] for row in data if "data" in row]
        if order_by:
            reverse = order_by.startswith("-")
            key = order_by.lstrip("-")
            results.sort(key=lambda x: x.get(key, ""), reverse=reverse)

        return results
    except Exception as e:
        print(f"[Supabase] Query Exception (URL: {url}): {e}")
        return []


async def get_all_documents(collection: str) -> list[dict]:
    """Get all documents in a collection (up to 1000 rows)."""
    return await query_collection(collection, limit=1000)


# ============================================================
# SEED HELPERS
# ============================================================

async def seed_providers(providers: list[dict]) -> int:
    """Seed providers into the database."""
    count = 0
    for provider in providers:
        doc_id = provider.get("id", str(uuid.uuid4())[:12])
        await create_document("providers", provider, doc_id)
        count += 1
    return count


async def seed_service_types(service_types: list[dict]) -> int:
    """Seed service types into the database."""
    count = 0
    for st in service_types:
        await create_document("serviceTypes", st, st["id"])
        count += 1
    return count


async def is_seeded() -> bool:
    """Check if database already has seed data."""
    try:
        providers = await query_collection("providers", limit=1)
        return len(providers) > 0
    except Exception:
        return False


# ============================================================
# AGENT TRACE OPERATIONS
# ============================================================

async def save_agent_trace(trace: dict) -> str:
    """Save an agent trace to the database."""
    return await create_document("agentTraces", trace)


async def get_traces_for_session(session_id: str) -> list[dict]:
    """Get all traces for a booking session."""
    return await query_collection(
        "agentTraces",
        filters=[("session_id", "==", session_id)],
        order_by="step_number",
    )


# ============================================================
# PROVIDER QUERY HELPERS
# ============================================================

async def get_providers_by_service(
    service_type: str,
    is_available: Optional[bool] = None,
    gender: Optional[str] = None,
    limit_count: int = 50,
) -> list[dict]:
    """Get providers filtered by service type, availability, and gender."""
    # Normalize service_type: lowercase, strip spaces
    service_type_normalized = service_type.lower().strip().replace(' ', '_')
    
    # Service Type Synonyms & Mappings
    synonyms = {
        "ac_technician": "ac_mechanic",
        "ac": "ac_mechanic",
        "air_conditioning": "ac_mechanic",
        "air_conditioner": "ac_mechanic",
        "housemaid": "house_maid",
        "cleaning": "house_maid",
        "maid": "house_maid",
        "garden": "gardener",
        "lawn": "gardener",
    }
    if service_type_normalized in synonyms:
        service_type_normalized = synonyms[service_type_normalized]

    print(f"[Discovery] Searching for service_type='{service_type_normalized}'")

    # Try exact match first (case-insensitive via ilike)
    filters = [("service_type_id", "==", service_type_normalized)]
    if gender:
        filters.append(("gender", "==", gender))

    providers = await query_collection("providers", filters=filters, limit=limit_count)
    print(f"[Discovery] Found {len(providers)} providers for service_type='{service_type_normalized}'")

    # If no results, try a broader search — get ALL providers and match in Python
    # This handles cases like 'Electrician' vs 'electrician' vs 'electric'
    if not providers:
        print(f"[Discovery] No exact match — trying broad search across all providers")
        all_providers = await query_collection("providers", limit=200)
        providers = [
            p for p in all_providers
            if service_type_normalized in str(p.get("service_type_id", "")).lower()
            or str(p.get("service_type_id", "")).lower() in service_type_normalized
        ]
        print(f"[Discovery] Broad search found {len(providers)} providers")

    # Filter is_available in Python (avoids JSONB boolean casting issues)
    if is_available is not None:
        providers = [p for p in providers if p.get("is_available") in [True, "true", 1, "1"]]
        print(f"[Discovery] After availability filter: {len(providers)} providers")

    # Filter gender in Python (ensures exact match, including for fallback search)
    if gender:
        gender_val = str(gender).lower().strip()
        providers = [p for p in providers if str(p.get("gender", "")).lower().strip() == gender_val]
        print(f"[Discovery] After gender filter: {len(providers)} providers")

    return providers

