import os
import requests
from core.config import settings

class TelegramService:
    def __init__(self):
        self.bot_token = os.getenv("TELEGRAM_BOT_TOKEN")
        self.chat_id = os.getenv("TELEGRAM_CHAT_ID") # Where to send the message
        self.base_url = f"https://api.telegram.org/bot{self.bot_token}"
        
        self.enabled = bool(self.bot_token and self.chat_id)
        if not self.enabled:
            print("[Telegram] Init failed (Missing Token or Chat ID) - using console logging")

    def send_message(self, message: str):
        if not self.enabled:
            print(f"\n[Telegram MOCK Message]\n{message}\n")
            return False
            
        try:
            url = f"{self.base_url}/sendMessage"
            payload = {
                "chat_id": self.chat_id,
                "text": message,
                "parse_mode": "Markdown"
            }
            response = requests.post(url, json=payload)
            if response.status_code == 200:
                print(f"[Telegram] Message sent successfully to {self.chat_id}")
                return True
            else:
                print(f"[Telegram] Failed to send message: {response.text}")
                return False
        except Exception as e:
            print(f"[Telegram] Error: {str(e)}")
            return False

# Global instance
telegram_client = TelegramService()
