"""
KabadiAI — Live Data Simulator
Pushes realistic mock scan, kabadiwalla, and alert data to Firestore
Run this in a separate terminal while the dashboard is open
"""

import firebase_admin
from firebase_admin import credentials, firestore
import os
import random
import time
from datetime import datetime

# ── INIT FIREBASE ─────────────────────────────────────────────────────────────
cred = credentials.Certificate(os.path.abspath(os.path.join(os.path.dirname(__file__), "firebase_key.json")))
firebase_admin.initialize_app(cred)
db = firestore.client()

# ── DATA CONFIG ───────────────────────────────────────────────────────────────
MATERIALS = [
    {"name": "plastic",    "price": 12,  "hazardous": False},
    {"name": "cardboard",  "price": 8,   "hazardous": False},
    {"name": "glass",      "price": 2,   "hazardous": False},
    {"name": "metal_scrap","price": 45,  "hazardous": False},
    {"name": "paper",      "price": 10,  "hazardous": False},
    {"name": "ewaste",     "price": 0,   "hazardous": True},
]

KABADIWALLAS = [
    {"name": "Raju Kumar",   "lat": 28.7041, "lng": 77.1025, "rating": 4.9},
    {"name": "Suresh Yadav", "lat": 28.6562, "lng": 77.2410, "rating": 4.7},
    {"name": "Mohan Lal",    "lat": 28.5355, "lng": 77.3910, "rating": 4.8},
    {"name": "Vijay Singh",  "lat": 28.6280, "lng": 77.0850, "rating": 4.6},
    {"name": "Ramesh Das",   "lat": 28.7280, "lng": 77.3200, "rating": 4.5},
]

ZONES = [
    {"name": "Rohini",         "lat": 28.7041, "lng": 77.1025},
    {"name": "Connaught Place","lat": 28.6315, "lng": 77.2167},
    {"name": "Lajpat Nagar",   "lat": 28.5655, "lng": 77.2431},
    {"name": "Dwarka",         "lat": 28.5921, "lng": 77.0460},
    {"name": "Noida Sector 62","lat": 28.6270, "lng": 77.3724},
]

ALERT_TEMPLATES = [
    "Li-ion battery detected in plastic bin",
    "CRT screen flagged — manual pickup required",
    "E-waste batch dispatched to certified recycler",
    "High copper density detected in zone",
    "Payout confirmed — kabadiwalla pickup complete",
]

# ── SEED INITIAL DATA ─────────────────────────────────────────────────────────
def seed_kabadiwallas():
    """Push kabadiwalla locations to Firestore"""
    print("Seeding kabadiwalla locations...")
    for k in KABADIWALLAS:
        db.collection("kabadiwallas").document(k["name"].replace(" ", "_")).set({
            "name": k["name"],
            "lat": k["lat"] + random.uniform(-0.01, 0.01),
            "lng": k["lng"] + random.uniform(-0.01, 0.01),
            "rating": k["rating"],
            "status": "active",
            "pickups_today": random.randint(5, 18),
            "earnings_today": random.randint(800, 3200),
            "last_updated": datetime.now().isoformat(),
        })
    print(f"  ✓ {len(KABADIWALLAS)} kabadiwallas seeded")

def seed_initial_scans(n=30):
    """Push initial scan history"""
    print(f"Seeding {n} initial scans...")
    for _ in range(n):
        material = random.choice(MATERIALS)
        zone = random.choice(ZONES)
        db.collection("scans").add({
            "material": material["name"],
            "price_per_kg": material["price"],
            "hazardous": material["hazardous"],
            "zone": zone["name"],
            "lat": zone["lat"] + random.uniform(-0.02, 0.02),
            "lng": zone["lng"] + random.uniform(-0.02, 0.02),
            "timestamp": datetime.now().isoformat(),
        })
    print(f"  ✓ {n} scans seeded")

def seed_initial_alerts(n=5):
    """Push initial alerts"""
    print(f"Seeding {n} initial alerts...")
    for i in range(n):
        zone = random.choice(ZONES)
        is_hazard = random.random() < 0.4
        db.collection("alerts").add({
            "message": random.choice(ALERT_TEMPLATES),
            "zone": zone["name"],
            "hazardous": is_hazard,
            "timestamp": datetime.now().isoformat(),
        })
    print(f"  ✓ {n} alerts seeded")

# ── LIVE SIMULATION LOOP ──────────────────────────────────────────────────────
def simulate_live(interval_seconds=5):
    """
    Continuously push new scans + alerts to Firestore every N seconds.
    Simulates real-time activity from households across Delhi.
    """
    print(f"\nLive simulation running — pushing data every {interval_seconds}s")
    print("Press Ctrl+C to stop\n")

    scan_count = 0
    alert_count = 0

    while True:
        try:
            # Push 1-3 new scans
            for _ in range(random.randint(1, 3)):
                material = random.choice(MATERIALS)
                zone = random.choice(ZONES)
                weight = round(random.uniform(0.3, 5.0), 2)
                value = round(weight * material["price"], 2)

                db.collection("scans").add({
                    "material": material["name"],
                    "price_per_kg": material["price"],
                    "hazardous": material["hazardous"],
                    "zone": zone["name"],
                    "lat": zone["lat"] + random.uniform(-0.02, 0.02),
                    "lng": zone["lng"] + random.uniform(-0.02, 0.02),
                    "timestamp": datetime.now().isoformat(),
                })
                scan_count += 1

                status = "⚠ HAZARDOUS" if material["hazardous"] else f"₹{material['price']} per kg"
                print(f"  [SCAN]  {material['name']:12} | {status} | {zone['name']}")

            # Push alert occasionally
            if random.random() < 0.3:
                zone = random.choice(ZONES)
                is_hazard = random.random() < 0.4
                msg = random.choice(ALERT_TEMPLATES)
                db.collection("alerts").add({
                    "message": msg,
                    "zone": zone["name"],
                    "hazardous": is_hazard,
                    "timestamp": datetime.now().isoformat(),
                })
                alert_count += 1
                print(f"  [ALERT] {msg[:50]} | {zone['name']}")

            # Update kabadiwalla positions slightly
            for k in KABADIWALLAS:
                doc_id = k["name"].replace(" ", "_")
                db.collection("kabadiwallas").document(doc_id).update({
                    "lat": k["lat"] + random.uniform(-0.005, 0.005),
                    "lng": k["lng"] + random.uniform(-0.005, 0.005),
                    "last_updated": datetime.now().isoformat(),
                })

            print(f"  Total — scans: {scan_count} | alerts: {alert_count}\n")
            time.sleep(interval_seconds)

        except KeyboardInterrupt:
            print("\nSimulator stopped.")
            break
        except Exception as e:
            print(f"Error: {e}")
            time.sleep(2)

# ── MAIN ──────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("=" * 50)
    print("  KabadiAI — Firebase Data Simulator")
    print("=" * 50)

    import sys
    seed_only = "--seed-only" in sys.argv

    # Seed initial data
    seed_kabadiwallas()
    seed_initial_scans(30)
    seed_initial_alerts(5)

    if seed_only:
        print("\n✅ Seed complete. Exiting (--seed-only mode).")
        print("   Run without --seed-only to start the live loop.")
        sys.exit(0)

    print("\nInitial data seeded! Starting live simulation...\n")
    print("Tip: use --seed-only to seed data once without continuous writes.\n")

    # Start live loop (writes every 5s — consumes Firestore quota)
    simulate_live(interval_seconds=5)