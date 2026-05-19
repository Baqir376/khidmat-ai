import urllib.request, json, urllib.error
data=json.dumps({'user_input': 'tile lagwane hain bathroom mein', 'lat': 24.8607, 'lng': 67.0011, 'womens_safety_mode': False, 'input_type': 'text'}).encode()
req=urllib.request.Request('http://127.0.0.1:8000/api/book', data=data, headers={'Content-Type': 'application/json'})
try:
    response = urllib.request.urlopen(req)
    res_data = response.read().decode('utf-8')
    with open('response_output.json', 'w', encoding='utf-8') as f:
        f.write(res_data)
    print("SUCCESS: Saved to response_output.json")
except urllib.error.HTTPError as e:
    print("ERROR:", e.code, e.read().decode())


