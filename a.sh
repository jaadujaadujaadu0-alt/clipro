#!/bin/bash

CAPTCHA_FILE="captcha.txt"
ALPHABET="abcdefghijklmnopqrstuvwxyz"

# Verification checks
if [ ! -f "$CAPTCHA_FILE" ]; then
    echo "❌ Error: $CAPTCHA_FILE not found!"
    exit 1
fi

LINE_COUNT=$(grep -c '^..*' "$CAPTCHA_FILE")
if [ "$LINE_COUNT" -lt 26 ]; then
    echo "❌ Error: $CAPTCHA_FILE only has $LINE_COUNT tokens. Need exactly 26."
    exit 1
fi

echo "================================================="
echo "🚀 Generating and Spawning 26 Isolated Crawlers "
echo "================================================="

# Clean up
rm -f crawler_*.py log_*.txt

for i in {0..25}; do
    LETTER=${ALPHABET:$i:1}
    LINE_NUM=$((i + 1))
    CAPTCHA_TOKEN=$(sed -n "${LINE_NUM}p" "$CAPTCHA_FILE" | tr -d '\r\n')

    cat << EOF > "crawler_${LETTER}.py"
import re
import time
import requests
import sys
from datetime import datetime, timezone
from requests import Session
from bs4 import BeautifulSoup

MY_LETTER = "${LETTER}"
CAPTCHA_TOKEN = "${CAPTCHA_TOKEN}"
TELEGRAM_BOT_TOKEN = "8756436897:AAH25gdphweqkxzinm92wy0WwWtVzAYodVc"
TELEGRAM_CHANNEL = "-1004442676807"

session = Session()
session.headers.update({
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36",
    "Referer": "https://www.lamix.org/tools",
})

def send_to_telegram(message: str):
    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
    payload = {"chat_id": TELEGRAM_CHANNEL, "text": message, "parse_mode": "Markdown"}
    try:
        requests.post(url, json=payload, timeout=10)
    except:
        pass

def send_terminal(term: str, results: dict):
    total = sum(results.values())
    hot = {k: v for k, v in results.items() if v > 0}
    hot_list = "\\n".join([f"• {c} ({v})" for c, v in sorted(hot.items(), key=lambda x: -x[1])])
    
    msg = f"🔥 **Terminal Range Found**\\n\\n**Prefix:** \`{term}\`\\n**Fires:** \`{total}\`\\n\\n**Hot:**\\n{hot_list if hot_list else 'None'}\\n\\n🕒 {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')}"
    send_to_telegram(msg)
    print(f"📤 [Telegram Sent] Terminal found for: {term}")
    sys.stdout.flush()

def scrape_site(search_term: str, csrf_token: str) -> dict:
    data = {
        "_token": csrf_token, 
        "search_term": search_term, 
        "search_in_body": "0", 
        "g-recaptcha-response": CAPTCHA_TOKEN
    }
    try:
        resp = session.post("https://www.lamix.org/tools", data=data, timeout=12)
        if resp.status_code != 200:
            return {}
        soup = BeautifulSoup(resp.text, "html.parser")
        results = {}
        for item in soup.select("ul#results-list li.result-item"):
            country_elem = item.select_one("span.country-name")
            if country_elem:
                country = country_elem.get_text(strip=True)
                results[country] = len(item.select("span.fire-emoji"))
        return results
    except:
        return {}

def get_csrf_token() -> str | None:
    try:
        resp = session.get("https://www.lamix.org/tools", timeout=10)
        match = re.search(r'name="_token" value="([^"]+)"', resp.text)
        return match.group(1) if match else None
    except:
        return None

def crawl_prefix(term: str, csrf_token: str) -> bool:
    results = scrape_site(term, csrf_token)
    time.sleep(1.0)
    
    has_hits = bool(results and any(v > 0 for v in results.values()))
    if not has_hits:
        return False

    print(f"✅ HIT Found: {term:<10} ({sum(results.values())} fires)")
    sys.stdout.flush()

    alphabet = 'abcdefghijklmnopqrstuvwxyz'
    any_child_hit = False
    
    for ch in alphabet:
        child_term = term + ch
        if crawl_prefix(child_term, csrf_token):
            any_child_hit = True
            
    if not any_child_hit:
        send_terminal(term, results)
        
    return True

def main():
    print(f"🚀 Worker [{MY_LETTER}] started.")
    sys.stdout.flush()
    csrf_token = get_csrf_token()
    if not csrf_token:
        print(f"❌ Worker [{MY_LETTER}] failed: CSRF error.")
        sys.stdout.flush()
        return
    crawl_prefix(MY_LETTER, csrf_token)

if __name__ == "__main__":
    main()
EOF

    # Added the -u flag for unbuffered output
    python3 -u "crawler_${LETTER}.py" > "log_${LETTER}.txt" 2>&1 &
    echo "🟢 Spawned: crawler_${LETTER}.py"
done

echo "-------------------------------------------------"
echo "🎯 26 crawlers active."
echo "👀 View branch 'a' hits: tail -f log_a.txt"
echo "================================================="
