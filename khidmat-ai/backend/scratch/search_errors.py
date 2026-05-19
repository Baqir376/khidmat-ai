import os
import re

frontend_dir = r"d:\Google_AI_Seekho_Antigravity\frontend"
for root, dirs, files in os.walk(frontend_dir):
    for file in files:
        if file.endswith(".dart"):
            path = os.path.join(root, file)
            with open(path, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read()
            if "no providers" in content.lower() or "service unavailable" in content.lower() or "no provider" in content.lower():
                print(f"Match in file: {path}")
                # print matching lines
                lines = content.splitlines()
                for i, line in enumerate(lines):
                    if "no providers" in line.lower() or "service unavailable" in line.lower() or "no provider" in line.lower():
                        print(f"  Line {i+1}: {line.strip()}")
