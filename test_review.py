import urllib.request
import json
import urllib.error

data = json.dumps({
    "provider_id": "8a837d53-a589-4e4d-b422-0a3b1d846789",
    "booking_id": "BK-CA32C3A5",
    "rating": 5.0,
    "review_text": "Excellent service!"
}).encode('utf-8')

req = urllib.request.Request(
    'http://127.0.0.1:8000/api/reviews', 
    data=data, 
    headers={'Content-Type': 'application/json'}
)

try:
    response = urllib.request.urlopen(req)
    print("SUCCESS:", response.read().decode())
except urllib.error.HTTPError as e:
    print("ERROR:", e.code, e.read().decode())
