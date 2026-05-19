import firebase_admin
from firebase_admin import credentials, messaging
import os
from config import settings

# Initialize Firebase Admin SDK
def init_firebase_admin():
    try:
        # Check if already initialized
        firebase_admin.get_app()
    except ValueError:
        # Not initialized yet
        if os.path.exists(settings.FIREBASE_CREDENTIALS_PATH):
            cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
            firebase_admin.initialize_app(cred, {
                'projectId': settings.FIREBASE_PROJECT_ID,
            })
            print(f"Firebase Admin initialized for project: {settings.FIREBASE_PROJECT_ID}")
        else:
            print(f"WARNING: Firebase credentials file not found at {settings.FIREBASE_CREDENTIALS_PATH}")

class NotificationService:
    def __init__(self):
        init_firebase_admin()

    def send_push_notification(self, token: str, title: str, body: str, data: dict = None):
        """
        Sends a push notification to a specific device token using FCM.
        """
        if not token:
            print("Cannot send notification: No FCM token provided.")
            return False

        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data if data else {},
            token=token,
        )

        try:
            response = messaging.send(message)
            print(f"Successfully sent FCM message: {response}")
            return True
        except Exception as e:
            print(f"Error sending FCM message: {e}")
            return False

    def send_multicast_notification(self, tokens: list, title: str, body: str, data: dict = None):
        """
        Sends a push notification to multiple device tokens.
        """
        if not tokens:
            print("Cannot send multicast notification: No FCM tokens provided.")
            return False

        message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data if data else {},
            tokens=tokens,
        )

        try:
            response = messaging.send_multicast(message)
            print(f"Successfully sent multicast message. {response.success_count} messages sent successfully.")
            return True
        except Exception as e:
            print(f"Error sending multicast FCM message: {e}")
            return False

notification_service = NotificationService()
