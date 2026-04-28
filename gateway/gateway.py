import requests
import os
import sqlite3
from flask import Flask, request, jsonify

app = Flask(__name__)
# Main backend endpoint
BACKEND_BASE = "http://127.0.0.1:5005"

# Gateway settings
DB_PATH = "gateway_history.db"

def init_db():
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS winners 
                 (payload_type TEXT PRIMARY KEY, winner_api TEXT)''')
    conn.commit()
    conn.close()

def get_payload_type(path, body=None):
    # Map request to Small/Medium/Large bucket
    if "full" in path: return "Large"
    if "/api/movies/" in path: return "Medium"
    if "/api/movies" in path: return "Small"
    
    # GraphQL simplified classification
    if body and "query" in body:
        q = body["query"]
        if "movieFull" in q or "cast" in q: return "Large"
        if "movieDetail" in q: return "Medium"
        return "Small"
    
    return "Small"

@app.route('/proxy/<path:p>', methods=['GET', 'POST'])
def proxy(p):
    ptype = get_payload_type(p, request.json)
    
    # Check if we have a recorded winner
    conn = sqlite3.connect(DB_PATH)
    winner = conn.cursor().execute("SELECT winner_api FROM winners WHERE payload_type=?", (ptype,)).fetchone()
    conn.close()
    
    target_api = winner[0] if winner else "rest" # Default fallback
    
    # Simple Routing Logic
    full_url = f"{BACKEND_BASE}/{p}"
    
    # In a real adaptive gateway, we might transform the request 
    # (e.g., if target is REST but input was GraphQL)
    # For this project, we assume the gateway already has equivalence rules
    # Here we just route the original request
    
    print(f"[Gateway] Routing {ptype} payload to {target_api.upper()} API...")
    
    # Mirror the actual request
    if request.method == 'POST':
        resp = requests.post(full_url, json=request.json)
    else:
        resp = requests.get(full_url)
        
    return (resp.text, resp.status_code, resp.headers.items())

if __name__ == "__main__":
    init_db()
    # Mock Learning results
    # In real operation, the gateway would perform the test itself 
    # and update winners table
    # For simulation, we seed from analysis results if available
    if os.path.exists("green_ranking.txt"):
        with open("green_ranking.txt", 'r') as f:
            lines = f.readlines()
            conn = sqlite3.connect(DB_PATH)
            for line in lines:
                payload, api = line.strip().split(':')
                conn.execute("INSERT OR REPLACE INTO winners (payload_type, winner_api) VALUES (?, ?)", (payload, api))
            conn.commit()
            conn.close()
            print("[Gateway] Winners table seeded from Green Ranking results.")

    app.run(port=5001)
