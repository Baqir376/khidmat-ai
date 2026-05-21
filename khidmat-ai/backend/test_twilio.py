import os
from dotenv import load_dotenv
from twilio.rest import Client

load_dotenv()

sid = os.getenv("TWILIO_ACCOUNT_SID")
token = os.getenv("TWILIO_AUTH_TOKEN")
twilio_num = os.getenv("TWILIO_PHONE_NUMBER")

if not sid or not token or not twilio_num:
    print("Error: Missing credentials!")
    exit(1)

client = Client(sid, token)
try:
    print("Testing sending message to a test phone number (+923331234567)...")
    # This will test if the credentials work for sending messages
    # and if the trial account limits it.
    msg = client.messages.create(
        body="KaamSaaz Twilio credentials test.",
        from_=twilio_num,
        to="+923331234567"
    )
    print("Success! SID:", msg.sid)
    print("Status:", msg.status)
except Exception as e:
    print("Twilio SMS send error:", e)
