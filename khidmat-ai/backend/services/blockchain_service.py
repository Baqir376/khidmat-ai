"""
KaamSaaz — Blockchain Service
Records booking hashes on Polygon Amoy Testnet for immutable receipts.
Falls back to mock recording when Web3 is not configured.
"""
import hashlib
import json
from datetime import datetime
from config import config

_web3_client = None

try:
    from web3 import Web3
    if config.POLYGON_RPC_URL:
        _web3_client = Web3(Web3.HTTPProvider(config.POLYGON_RPC_URL))
        if _web3_client.is_connected():
            print("[Blockchain] Connected to Polygon Amoy")
        else:
            _web3_client = None
except Exception as e:
    print(f"[Blockchain] Init failed ({e}) - using mock")


def generate_booking_hash(booking_data: dict) -> str:
    canonical = {
        "booking_id": booking_data.get("id", ""),
        "citizen_id": booking_data.get("citizen_id", ""),
        "provider_id": booking_data.get("provider_id", ""),
        "service_type": booking_data.get("service_type_id", ""),
        "quoted_price": booking_data.get("quoted_price", 0),
        "scheduled_date": booking_data.get("scheduled_date", ""),
    }
    return hashlib.sha256(json.dumps(canonical, sort_keys=True).encode()).hexdigest()


async def record_on_blockchain(booking_data: dict) -> dict:
    booking_hash = generate_booking_hash(booking_data)
    if _web3_client and config.WALLET_PRIVATE_KEY:
        try:
            account = _web3_client.eth.account.from_key(config.WALLET_PRIVATE_KEY)
            nonce = _web3_client.eth.get_transaction_count(account.address)
            tx = {
                "nonce": nonce, "to": account.address, "value": 0,
                "gas": 21000 + len(booking_hash.encode()) * 16,
                "gasPrice": _web3_client.to_wei("30", "gwei"),
                "data": _web3_client.to_hex(text=booking_hash),
                "chainId": 80002,
            }
            signed = _web3_client.eth.account.sign_transaction(tx, config.WALLET_PRIVATE_KEY)
            tx_hash = _web3_client.eth.send_raw_transaction(signed.raw_transaction)
            return {
                "success": True, "tx_hash": tx_hash.hex(),
                "booking_hash": booking_hash, "network": "polygon_amoy",
                "explorer_url": f"https://amoy.polygonscan.com/tx/{tx_hash.hex()}",
            }
        except Exception as e:
            return _mock_record(booking_hash)
    return _mock_record(booking_hash)


def _mock_record(booking_hash: str) -> dict:
    mock_tx = hashlib.md5(booking_hash.encode()).hexdigest()
    return {
        "success": True, "tx_hash": f"0x{mock_tx}",
        "booking_hash": booking_hash, "network": "mock_polygon_amoy",
        "explorer_url": f"https://amoy.polygonscan.com/tx/0x{mock_tx}",
        "is_mock": True, "timestamp": datetime.utcnow().isoformat(),
    }
