"""
KaamSaaz — Payment Service
JazzCash/EasyPaisa sandbox simulation and escrow management.
"""
import hashlib
import uuid
from datetime import datetime


async def simulate_jazzcash_payment(
    amount: int, booking_id: str, phone: str
) -> dict:
    """Simulate JazzCash payment in sandbox mode."""
    tx_id = f"JC-{uuid.uuid4().hex[:8].upper()}"
    return {
        "success": True,
        "transaction_id": tx_id,
        "amount_pkr": amount,
        "phone": phone,
        "booking_id": booking_id,
        "method": "jazzcash_sandbox",
        "status": "completed",
        "timestamp": datetime.utcnow().isoformat(),
        "receipt_hash": hashlib.sha256(
            f"{tx_id}{amount}{booking_id}".encode()
        ).hexdigest()[:16],
    }


async def simulate_easypaisa_payment(
    amount: int, booking_id: str, phone: str
) -> dict:
    """Simulate EasyPaisa payment in sandbox mode."""
    tx_id = f"EP-{uuid.uuid4().hex[:8].upper()}"
    return {
        "success": True,
        "transaction_id": tx_id,
        "amount_pkr": amount,
        "phone": phone,
        "booking_id": booking_id,
        "method": "easypaisa_sandbox",
        "status": "completed",
        "timestamp": datetime.utcnow().isoformat(),
    }


async def create_escrow(booking_id: str, amount: int) -> dict:
    """Create escrow hold for a booking (simulated)."""
    return {
        "escrow_id": f"ESC-{uuid.uuid4().hex[:8].upper()}",
        "booking_id": booking_id,
        "amount_pkr": amount,
        "status": "held",
        "created_at": datetime.utcnow().isoformat(),
        "release_condition": "service_completed",
    }


async def release_escrow(escrow_id: str) -> dict:
    """Release escrow funds to provider (simulated)."""
    return {
        "escrow_id": escrow_id,
        "status": "released",
        "released_at": datetime.utcnow().isoformat(),
    }
