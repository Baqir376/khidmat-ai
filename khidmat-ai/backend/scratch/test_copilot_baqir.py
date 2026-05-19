import requests

def main():
    try:
        url = "http://localhost:8000/api/admin/copilot"
        # Test in English
        payload_en = {
            "message": "how many jobs did Baqir Raza complete?",
            "history": []
        }
        res = requests.post(url, json=payload_en)
        print("English query status:", res.status_code)
        print("English query response:")
        print(res.json().get("response"))
        print("-" * 40)
        
        # Test in Roman Urdu
        payload_ur = {
            "message": "Baqir Raza ne kitne jobs kiye hain?",
            "history": []
        }
        res2 = requests.post(url, json=payload_ur)
        print("Roman Urdu query status:", res2.status_code)
        print("Roman Urdu query response:")
        print(res2.json().get("response"))
    except Exception as e:
        print("Error calling Copilot API:", e)

if __name__ == "__main__":
    main()
