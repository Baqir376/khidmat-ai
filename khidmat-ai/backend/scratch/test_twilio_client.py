import sys
sys.path.append('.')
import traceback
from twilio.rest import Client
from config import config

print("Sid:", config.TWILIO_ACCOUNT_SID)
print("Auth:", config.TWILIO_AUTH_TOKEN[:4] + "..." if config.TWILIO_AUTH_TOKEN else None)
print("Phone:", config.TWILIO_PHONE_NUMBER)

try:
    client = Client(config.TWILIO_ACCOUNT_SID, config.TWILIO_AUTH_TOKEN)
    print("Attempting to send message...")
    msg = client.messages.create(
        body="This is a test message from Twilio backend.",
        from_=config.TWILIO_PHONE_NUMBER,
        to="+923001234567"
    )
    print("Message sent successfully! Sid:", msg.sid)
except Exception as e:
    print("Twilio Client Error on messages.create:")
    traceback.print_exc()
