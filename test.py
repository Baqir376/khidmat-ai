import urllib.request, json, urllib.error
data=json.dumps({'user_input': 'AC kharab hai', 'lat': 31.52, 'lng': 74.35, 'womens_safety_mode': False, 'input_type': 'text'}).encode()
req=urllib.request.Request('http://127.0.0.1:8000/api/book', data=data, headers={'Content-Type': 'application/json'})
try:
    urllib.request.urlopen(req)
except urllib.error.HTTPError as e:
    print(e.read().decode())
