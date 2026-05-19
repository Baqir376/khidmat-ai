import requests
import json

def test_copilot():
    url = "http://localhost:8000/api/admin/copilot"
    payload = {
        "message": "mujhe ye batao sab se kam income kis ki hai",
        "history": [
            {
                "role": "ai",
                "text": "Assalam-o-Alaikum Administrator. I am the Khidmat Copilot, connected directly to your live database. Ask me any queries about bookings, active provider earnings, or agent reasoning traces."
            },
            {
                "role": "user",
                "text": "mujhe ye batao sab se kam income kis ki hai"
            }
        ]
    }
    
    print("Sending request to", url)
    try:
        response = requests.post(url, json=payload)
        print("Status Code:", response.status_code)
        print("Response JSON:")
        print(json.dumps(response.json(), indent=2))
    except Exception as e:
        print("Error connecting to copilot endpoint:", e)

if __name__ == "__main__":
    test_copilot()
