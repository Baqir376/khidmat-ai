import re

with open(r"d:\Google_AI_Seekho_Antigravity\frontend\lib\screens\home_screen.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if "submitrequest" in line.lower() or "error" in line.lower() or "exception" in line.lower():
        print(f"Line {i+1}: {line.strip()}")
