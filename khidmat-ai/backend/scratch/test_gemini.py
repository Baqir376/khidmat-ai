import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import asyncio
from config import config

async def main():
    try:
        import google.generativeai as genai
        genai.configure(api_key=config.GEMINI_API_KEY)
        model = genai.GenerativeModel("models/gemini-2.5-flash")
        print("Calling generate_content...")
        response = model.generate_content("Say hello in Roman Urdu")
        print("Response received:")
        print(response.text)
    except Exception as e:
        print("Gemini API call failed:", e)

if __name__ == '__main__':
    asyncio.run(main())
