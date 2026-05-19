import re

with open(r"d:\Google_AI_Seekho_Antigravity\frontend\lib\screens\booking_screen.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if any(keyword in line.lower() for keyword in ["unavailable", "exception", "no provider", "client"]):
        print(f"Line {i+1}: {line.strip()}")
