"""
KaamSaaz — Email Service
Sends verification emails and alerts.
Falls back to Telegram Bot notification and console logging during development.
"""
import os
import requests
from config import config

SENDGRID_API_KEY = os.getenv("SENDGRID_API_KEY", "")
SENDGRID_FROM_EMAIL = os.getenv("SENDGRID_FROM_EMAIL", "verification@khidmat.ai")
TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
# Note: In production or development, the developer's chat ID is set to receive test notifications.
# If TELEGRAM_CHAT_ID in env is "your_chat_id" or empty, we skip sending.
TELEGRAM_CHAT_ID = os.getenv("TELEGRAM_CHAT_ID", "")
SMTP_EMAIL = os.getenv("SMTP_EMAIL", "")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")

async def send_email(to_email: str, subject: str, body: str) -> dict:
    """Send an email using SendGrid, falling back to Telegram / Console when mock or unconfigured."""
    import asyncio
    
    # 1. Attempt SendGrid if API Key is populated and not the placeholder
    if SENDGRID_API_KEY and SENDGRID_API_KEY != "your_sendgrid_key":
        try:
            url = "https://api.sendgrid.com/v3/mail/send"
            headers = {
                "Authorization": f"Bearer {SENDGRID_API_KEY}",
                "Content-Type": "application/json"
            }
            payload = {
                "personalizations": [
                    {
                        "to": [{"email": to_email}],
                        "subject": subject
                    }
                ],
                "from": {
                    "email": SENDGRID_FROM_EMAIL,
                    "name": "KaamSaaz"
                },
                "content": [
                    {
                        "type": "text/plain",
                        "value": body
                    }
                ]
            }
            
            # Non-blocking post request
            response = await asyncio.to_thread(
                requests.post, url, json=payload, headers=headers, timeout=5
            )
            if response.status_code in [200, 201, 202]:
                print(f"[SendGrid] Email sent successfully to {to_email}")
                return {"success": True, "service": "sendgrid", "status": "sent"}
            else:
                print(f"[SendGrid Error] Status: {response.status_code}, Body: {response.text}")
                pass # Continuing to fallback so development is not blocked
        except Exception as e:
            print(f"[SendGrid Exception] {e}")
            pass # Continuing to fallback so development is not blocked
            
    # 2. SMTP Fallback (Gmail etc)
    if SMTP_EMAIL and SMTP_PASSWORD and SMTP_EMAIL != "your_email@gmail.com":
        try:
            import smtplib
            from email.mime.text import MIMEText
            from email.mime.multipart import MIMEMultipart

            msg = MIMEMultipart()
            msg['From'] = f"KaamSaaz <{SMTP_EMAIL}>"
            msg['To'] = to_email
            msg['Subject'] = subject
            msg.attach(MIMEText(body, 'plain'))

            def _send_smtp():
                server = smtplib.SMTP('smtp.gmail.com', 587)
                server.starttls()
                server.login(SMTP_EMAIL, SMTP_PASSWORD)
                server.send_message(msg)
                server.quit()
                
            await asyncio.to_thread(_send_smtp)
            print(f"[SMTP] Email sent successfully to {to_email}")
            return {"success": True, "service": "smtp", "status": "sent"}
        except Exception as e:
            print(f"[SMTP Error] {e}")
            pass # Continuing to fallback so development is not blocked
            
    # 3. Telegram Fallback for developer convenience
    if TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID and TELEGRAM_CHAT_ID != "your_chat_id":
        try:
            telegram_url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
            text_message = f"📧 *[Email to {to_email}]*\n*Subject:* {subject}\n\n{body}"
            await asyncio.to_thread(
                requests.post, telegram_url,
                json={"chat_id": TELEGRAM_CHAT_ID, "text": text_message, "parse_mode": "Markdown"},
                timeout=3
            )
            print(f"[Telegram Email Fallback] Code sent for {to_email}")
            return {"success": True, "service": "telegram", "status": "sent"}
        except Exception as te:
            print(f"[Telegram Email Fallback Error] {te}")
            
    # 4. Console mock fallback
    print(f"[Email MOCK] To: {to_email} | Subject: {subject} | Body: {body}")
    return {"success": True, "service": "mock", "status": "mock_sent"}
