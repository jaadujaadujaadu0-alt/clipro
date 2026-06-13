import os
import re
import time
import requests
from datetime import datetime, timezone
from requests import Session
from bs4 import BeautifulSoup
from typing import Dict, List
from threading import Lock

# ========================= CONFIG =========================
TELEGRAM_BOT_TOKEN = "8756436897:AAH25gdphweqkxzinm92wy0WwWtVzAYodVc"
TELEGRAM_CHANNEL = "-1004442676807"
CAPTCHA_FILE = "captcha.txt"
# ==========================================================

# Thread-safe locks for clean output/delivery
print_lock = Lock()
telegram_lock = Lock()

def load_captchas() -> List[str]:
    if not os.path.exists(CAPTCHA_FILE):
        with print_lock:
            print(f"❌ Error: {CAPTCHA_FILE} missing!")
        return []
    with open(CAPTCHA_FILE, "r", encoding="utf-8") as f:
        tokens = [line.strip() for line in f if line.strip()]
    return tokens

def send_to_telegram(message: str):
    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
    payload = {"chat_id": TELEGRAM_CHANNEL, "text": message, "parse_mode": "Markdown"}
    try:
        with telegram_lock:
            requests.post(url, json=payload, timeout=10)
    except:
        pass

def send_terminal(term: str, results: dict):
    total = sum(results.values())
    hot = {k: v for k, v in results.items() if v > 0}
    hot_list = "\n".join([f"• {c} ({v})" for c, v in sorted(hot.items(), key=lambda x: -x[1])])
    
    msg = f"🔥 **Terminal Range Found**\n\n**Prefix:** `{term}`\n**Fires:** `{total}`\n\n**Hot:**\n{hot_list if hot_list else 'None'}\n\n🕒 {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')}"
    send_to_telegram(msg)
    with print_lock:
        print(f"\n📤 [Telegram Sent] Terminal found for: {term}\n")

def create_isolated_session() -> Session:
    """Creates a fresh session per root branch to ensure no data corruption."""
    local_session = Session()
    local_session.headers.update({
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36",
        "Referer": "https://www.lamix.org/tools",
    })
    return local_session

def scrape_site(local_session: Session, search_term: str, csrf_token: str, captcha_token: str) -> dict:
    data = {
        "_token": csrf_token, 
        "search_term": search_term, 
        "search_in_body": "0", 
        "g-recaptcha-response": captcha_token
    }
    try:
        resp = local_session.post("https://www.lamix.org/tools", data=data, timeout=12)
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

def get_csrf_token(local_session: Session) -> str | None:
    try:
        resp = local_session.get("https://www.lamix.org/tools", timeout=10)
        match = re.search(r'name="_token" value="([^"]+)"', resp.text)
        return match.group(1) if match else None
    except:
        return None

def crawl_prefix(local_session: Session, term: str, csrf_token: str, captcha_token: str) -> bool:
    """
    Crawls a prefix branch recursively. 
    Returns True if this prefix or ANY of its children had valid results.
    """
    results = scrape_site(local_session, term, csrf_token, captcha_token)
    time.sleep(0.6)  # Compliance delay to protect against IP block/rate limits
    
    has_hits = bool(results and any(v > 0 for v in results.values()))
    
    if not has_hits:
        return False

    # Print ONLY when a valid hit is found
    with print_lock:
        print(f"✅ HIT Found: {term:<10} ({sum(results.values())} fires)")

    alphabet = 'abcdefghijklmnopqrstuvwxyz'
    any_child_hit = False
    
    for ch in alphabet:
        child_term = term + ch
        # Recurse down the branch
        child_hit = crawl_prefix(local_session, child_term, csrf_token, captcha_token)
        if child_hit:
            any_child_hit = True
            
    # If this current node was a HIT, but every single child below it completely failed,
    # it means it's the absolute end of the chain (Terminal).
    if not any_child_hit:
        send_terminal(term, results)
        
    return True

def main():
    print("========================================")
    print("   LAMIX SEQUENTIAL TERMINAL CRAWLER")
    print("========================================")
    
    captchas = load_captchas()
    if len(captchas) < 26:
        print(f"❌ Error: Not enough tokens! Need 26, found {len(captchas)} in {CAPTCHA_FILE}")
        return

    alphabet = 'abcdefghijklmnopqrstuvwxyz'
    
    print(f"⚡ Running sequentially (Worker=1, Batch=1)...")
    print("----------------------------------------")
    
    # Process each root letter sequence one by one
    for i, letter in enumerate(alphabet):
        captcha_token = captchas[i]
        
        # Fresh network bucket for this alphabet stream
        local_session = create_isolated_session()
        
        with print_lock:
            print(f"🔄 Root [{letter}] -> Initializing fresh session & CSRF token...")
            
        csrf_token = get_csrf_token(local_session)
        if not csrf_token:
            with print_lock:
                print(f"❌ Root [{letter}] skipped: Failed to grab CSRF token.")
            continue
            
        # Execute the recursive path down this root letter tree completely
        crawl_prefix(local_session, letter, csrf_token, captcha_token)

    print("\n🏁 All letters finished execution.")

if __name__ == "__main__":
    main()
