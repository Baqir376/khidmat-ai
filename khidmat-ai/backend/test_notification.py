import os
import sys

# Ensure backend directory is in path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from services.notification_service import notification_service

def run_test():
    print("=== Khidmat AI Push Notification Tester ===")
    print("To test a push notification, we need your device's FCM Token.")
    print("If you just ran the Flutter app, look in your debug console for:")
    print("'FCM Token: <your-long-token-here>'")
    print("------------------------------------------")
    
    token = input("Paste your FCM Token here: ").strip()
    
    if not token:
        print("No token provided. Exiting.")
        return
        
    print("\nSending test notification...")
    
    success = notification_service.send_push_notification(
        token=token,
        title="New Job Request!",
        body="A customer in Gulberg needs a plumber. Tap to view.",
        data={
            "job_id": "TEST_JOB_123",
            "type": "new_booking"
        }
    )
    
    if success:
        print("\n✅ Notification sent successfully!")
        print("Check your emulator/device. If the app is closed/backgrounded, it will be in the system tray.")
        print("If the app is open, you should see a green SnackBar popup.")
    else:
        print("\n❌ Failed to send notification. Check the error logs above.")

if __name__ == "__main__":
    run_test()
