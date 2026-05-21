"""
KaamSaaz — Interactive Test Suite for AI Chatbot
Tests multiple conversation turns, language detection, intent mapping,
and action routing.
"""
import sys
import asyncio
from fastapi.testclient import TestClient
from main import app

# Force stdout to use UTF-8 to prevent encoding errors on Windows
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

client = TestClient(app)

def print_banner(text: str):
    print("\n" + "=" * 80)
    print(f" {text}")
    print("=" * 80)

def simulate_chat(message: str, history: list, language: str = "en") -> dict:
    """Send a message to the /api/ai-chat endpoint with history."""
    payload = {
        "message": message,
        "history": history,
        "lat": 24.8607,
        "lng": 67.0099,
        "language": language
    }
    response = client.post("/api/ai-chat", json=payload)
    assert response.status_code == 200, f"API failed with {response.status_code}: {response.text}"
    return response.json()

async def main():
    # =========================================================================
    # TEST CASE 1: Electrician flow (Roman Urdu)
    # =========================================================================
    print_banner("TEST CASE 1: Electrician Intent (Roman Urdu)")
    
    history = []
    
    # Step 1. Greeting
    msg = "Assalam o Alaikum"
    print(f"User:  {msg}")
    res = simulate_chat(msg, history)
    reply = res["reply"]
    action = res["action"]
    print(f"AI:    {reply}")
    print(f"Meta:  Action={action} | Service={res.get('service_type')} | Time={res.get('extracted_time')}")
    history.append({"role": "user", "text": msg})
    history.append({"role": "assistant", "text": reply})
    
    # Step 2. Problem statement ("fan kharab hai")
    print("-" * 50)
    msg = "fan kharab hai"
    print(f"User:  {msg}")
    res = simulate_chat(msg, history)
    reply = res["reply"]
    action = res["action"]
    print(f"AI:    {reply}")
    print(f"Meta:  Action={action} | Service={res.get('service_type')} | Time={res.get('extracted_time')}")
    assert res.get("service_type") == "electrician", "Failed to detect electrician service from 'fan kharab hai'"
    history.append({"role": "user", "text": msg})
    history.append({"role": "assistant", "text": reply})
    
    # Step 3. Confirming time ("aaj shaam 6 baje")
    print("-" * 50)
    msg = "aaj shaam 6 baje"
    print(f"User:  {msg}")
    res = simulate_chat(msg, history)
    reply = res["reply"]
    action = res["action"]
    print(f"AI:    {reply}")
    print(f"Meta:  Action={action} | Service={res.get('service_type')} | Time={res.get('extracted_time')} | Redirect={res.get('redirect_query')}")
    assert action == "show_providers", "Failed to trigger provider search action when time was given"
    assert res.get("service_type") == "electrician", "Lost service type context in final turn"
    assert res.get("extracted_time") is not None, "Failed to extract time hint"

    # =========================================================================
    # TEST CASE 2: AC Mechanic flow (English)
    # =========================================================================
    print_banner("TEST CASE 2: AC Mechanic Intent (English)")
    
    history = []
    
    # Step 1. Problem statement ("My AC is not cooling, need urgent repair")
    msg = "My AC is not cooling, need urgent repair"
    print(f"User:  {msg}")
    res = simulate_chat(msg, history)
    reply = res["reply"]
    action = res["action"]
    print(f"AI:    {reply}")
    print(f"Meta:  Action={action} | Service={res.get('service_type')} | Time={res.get('extracted_time')}")
    assert res.get("service_type") == "ac_mechanic", "Failed to detect AC mechanic from 'AC not cooling'"
    history.append({"role": "user", "text": msg})
    history.append({"role": "assistant", "text": reply})
    
    # Step 2. Confirming time ("now")
    print("-" * 50)
    msg = "now, immediately"
    print(f"User:  {msg}")
    res = simulate_chat(msg, history)
    reply = res["reply"]
    action = res["action"]
    print(f"AI:    {reply}")
    print(f"Meta:  Action={action} | Service={res.get('service_type')} | Time={res.get('extracted_time')} | Redirect={res.get('redirect_query')}")
    assert action == "show_providers", "Failed to trigger provider search"
    assert res.get("service_type") == "ac_mechanic", "Lost service type context"

    # =========================================================================
    # TEST CASE 3: Cooking Intent (Roman Urdu)
    # =========================================================================
    print_banner("TEST CASE 3: Cooking Intent (Roman Urdu)")
    
    history = []
    
    # Step 1. Problem statement ("khana pakane k liye cook chahiye")
    msg = "khana pakane k liye cook chahiye"
    print(f"User:  {msg}")
    res = simulate_chat(msg, history)
    reply = res["reply"]
    action = res["action"]
    print(f"AI:    {reply}")
    print(f"Meta:  Action={action} | Service={res.get('service_type')} | Time={res.get('extracted_time')}")
    assert res.get("service_type") == "cook", "Failed to detect cook service from 'khana pakane k liye cook'"
    history.append({"role": "user", "text": msg})
    history.append({"role": "assistant", "text": reply})
    
    # Step 2. Confirming time ("kal subah 9 baje")
    print("-" * 50)
    msg = "kal subah 9 baje"
    print(f"User:  {msg}")
    res = simulate_chat(msg, history)
    reply = res["reply"]
    action = res["action"]
    print(f"AI:    {reply}")
    print(f"Meta:  Action={action} | Service={res.get('service_type')} | Time={res.get('extracted_time')} | Redirect={res.get('redirect_query')}")
    assert action == "show_providers", "Failed to trigger provider search for cook"
    assert res.get("service_type") == "cook", "Lost cook service type context"

    # =========================================================================
    # TEST CASE 4: Guard rails / Irrelevant request
    # =========================================================================
    print_banner("TEST CASE 4: Irrelevant Request (Guard rails)")
    
    history = []
    msg = "tell me the recipe for chicken biryani"
    print(f"User:  {msg}")
    res = simulate_chat(msg, history)
    reply = res["reply"]
    action = res["action"]
    print(f"AI:    {reply}")
    print(f"Meta:  Action={action} | Service={res.get('service_type')}")
    assert action == "chat", "Incorrectly triggered booking action for irrelevant text"
    assert res.get("service_type") is None, "Incorrectly assigned a service to irrelevant text"

    print("\n" + "=" * 80)
    print(" ALL TEST CASES COMPLETED SUCCESSFULLY!")
    print("=" * 80 + "\n")

if __name__ == "__main__":
    asyncio.run(main())
