import re

def test_regex():
    prompt = """You are negotiating price for a tutor service in Pakistan.

Provider: Test Tutor
Quoted Price: Rs 5000
Fair Market Range: Rs 500 - Rs 2000

Generate a respectful counter-offer in Roman Urdu style.
Return JSON with: counter_offer_price, message_to_provider, message_to_citizen, reasoning"""

    quoted_match = re.search(r'(?:Quoted Price|quoted):\s*(?:Rs\s*)?(\d+)', prompt, re.IGNORECASE)
    fair_range_match = re.search(r'(?:Fair Market Range|range):\s*(?:Rs\s*)?(\d+)\s*-\s*(?:Rs\s*)?(\d+)', prompt, re.IGNORECASE)

    print("quoted_match:", quoted_match.groups() if quoted_match else None)
    print("fair_range_match:", fair_range_match.groups() if fair_range_match else None)

if __name__ == "__main__":
    test_regex()
