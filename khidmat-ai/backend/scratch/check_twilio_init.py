import sys
sys.path.append('.')
from config import config
from services.twilio_service import _twilio_client

print(f"TWILIO_ACCOUNT_SID: '{config.TWILIO_ACCOUNT_SID}'")
print(f"TWILIO_AUTH_TOKEN: '{config.TWILIO_AUTH_TOKEN}'")
print(f"TWILIO_PHONE_NUMBER: '{config.TWILIO_PHONE_NUMBER}'")
print(f"Twilio client initialized: {_twilio_client is not None}")
