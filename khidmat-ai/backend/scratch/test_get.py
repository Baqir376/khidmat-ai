import requests
try:
    res = requests.get("https://api.twilio.com", timeout=10)
    print("Status code:", res.status_code)
    print("Headers:", res.headers)
except Exception as e:
    print("Error:", e)
