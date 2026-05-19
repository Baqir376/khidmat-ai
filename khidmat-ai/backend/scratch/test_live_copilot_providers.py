import requests
import json

def test_provider(name, urdu_query=None):
    url = "http://localhost:8000/api/admin/copilot"
    
    # 1. Query in English
    payload_en = {
        "message": f"How many completed jobs and total earnings does {name} have according to the registry?",
        "history": []
    }
    try:
        res = requests.post(url, json=payload_en)
        if res.status_code == 200:
            print(f"[{name}] English Response:")
            print(res.json().get("response"))
        else:
            print(f"[{name}] English failed with status {res.status_code}")
    except Exception as e:
        print(f"[{name}] English error:", e)
        
    print("-" * 50)
    
    # 2. Query in Roman Urdu if provided
    if urdu_query:
        payload_ur = {
            "message": urdu_query,
            "history": []
        }
        try:
            res = requests.post(url, json=payload_ur)
            if res.status_code == 200:
                print(f"[{name}] Roman Urdu Response:")
                print(res.json().get("response"))
            else:
                print(f"[{name}] Roman Urdu failed with status {res.status_code}")
        except Exception as e:
            print(f"[{name}] Roman Urdu error:", e)
        print("=" * 60)

def main():
    print("Testing Live Copilot Provider Statistics...\n")
    test_provider("Muhammad Ali", "Muhammad Ali ke kitne jobs completed hain aur usne kitna kamaya hai?")
    test_provider("Sajid Khan", "Sajid Khan ne kitne paise kamaye hain?")
    test_provider("Babar Azam", "Babar Azam ki total earning aur completed jobs kitne hain?")
    test_provider("Yasir Shah", "Yasir Shah ne kitne jobs kiye hain?")
    test_provider("Baqir Raza", "Baqir Raza ne kitne jobs complete kiye hain?")

if __name__ == "__main__":
    main()
