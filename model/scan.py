"""
KabadiAI — Live Camera Scanner
Opens webcam, runs YOLOv11-seg inference, pushes {material, confidence,
timestamp} to Firebase. Weight is NOT estimated from pixels — it is
confirmed physically by the kabadiwalla's scale at pickup time.

Run: python scan.py
"""

import cv2
import numpy as np
import firebase_admin
from firebase_admin import credentials, firestore
from ultralytics import YOLO
from datetime import datetime
import time
import os

# ── CONFIG ────────────────────────────────────────────────────────────────────
MODEL_PATH   = os.path.abspath(os.path.join(os.path.dirname(__file__), "kabadiai_best.pt"))
FIREBASE_KEY = "../Frontend/firebase_key.json"

WINDOW_NAME   = "KabadiAI - Live Scanner"
FRAME_WIDTH   = 1280
FRAME_HEIGHT  = 720

# The 6 classes the model was trained on (must match training order)
CLASSES = ['glass', 'metal_scrap', 'paper', 'cardboard', 'plastic', 'ewaste']

# Reference price table — displayed to user AFTER kabadiwalla confirms weight
PRICE_PER_KG = {
    'glass':       2,
    'metal_scrap': 45,
    'paper':       10,
    'cardboard':   8,
    'plastic':     12,
    'ewaste':      0,   # hazardous — routed to certified recycler, not sold
}

HAZARDOUS = {'ewaste'}

# Nearest certified e-waste drop-off centres (Delhi NCR)
EWASTE_DROPOFFS = [
    {"name": "GreenTech Recyclers",      "address": "Okhla Industrial Area, Phase II, New Delhi",    "phone": "011-2638-5100"},
    {"name": "E-Parisaraa",              "address": "Sector 18, Gurugram, Haryana",                  "phone": "0124-421-0300"},
    {"name": "Attero Recycling",         "address": "A-9, Sector 59, Noida, UP",                     "phone": "0120-416-7100"},
    {"name": "Cerebra Integrated Tech",  "address": "Jasola District Centre, New Delhi",             "phone": "011-4054-4100"},
    {"name": "CPCB Authorised Drop-off", "address": "Bhikaji Cama Place, New Delhi",                 "phone": "011-2307-0200"},
]

# Colors per class (BGR for OpenCV)
COLORS = {
    'glass':       (255, 200,   0),
    'metal_scrap': (  0, 200, 255),
    'paper':       (200, 255,   0),
    'cardboard':   (  0, 165, 255),
    'plastic':     (  0, 255, 100),
    'ewaste':      (  0,   0, 255),
}

# Demo location — Delhi NCR centre (scanner adds small random jitter)
DEMO_LAT = 28.6139
DEMO_LNG = 77.2090

CONF_THRESHOLD = 0.30   # lower = detects more, possibly less accurate
SCAN_COOLDOWN  = 3      # seconds between scans


# ── INIT FIREBASE ─────────────────────────────────────────────────────────────
def init_firebase():
    if not firebase_admin._apps:
        cred = credentials.Certificate(FIREBASE_KEY)
        firebase_admin.initialize_app(cred)
    return firestore.client()


# ── PUSH SCAN TO FIREBASE ─────────────────────────────────────────────────────
def push_scan(db, class_name, confidence):
    """
    Push scan result to Firestore.
    Schema: {material, confidence, timestamp, hazardous, zone, lat, lng}
    NOTE: weight_kg is NOT included — weight is confirmed by kabadiwalla's
    physical scale at pickup time. Final price = actual_weight × price_per_kg.
    """
    try:
        db.collection("scans").add({
            "material":    class_name,
            "confidence":  round(confidence, 3),
            "price_per_kg": PRICE_PER_KG.get(class_name, 0),
            "hazardous":   class_name in HAZARDOUS,
            "zone":        "Live Scan - Delhi",
            "lat":         DEMO_LAT + float(np.random.uniform(-0.01, 0.01)),
            "lng":         DEMO_LNG + float(np.random.uniform(-0.01, 0.01)),
            "timestamp":   datetime.now().isoformat(),
            "source":      "camera",
        })
    except Exception as e:
        print(f"  ⚠ Firebase push failed (scan): {e}")


def push_alert(db, message, is_hazard=False, zone="Live Scan - Delhi"):
    """Push alert to Firestore alerts collection."""
    try:
        db.collection("alerts").add({
            "message":   message,
            "zone":      zone,
            "hazardous": is_hazard,
            "timestamp": datetime.now().isoformat(),
        })
    except Exception as e:
        print(f"  ⚠ Firebase push failed (alert): {e}")


# ── DRAW OVERLAY ──────────────────────────────────────────────────────────────
def draw_overlay(frame, detections):
    """Draw segmentation masks, bounding boxes, and labels on a frame."""
    overlay = frame.copy()

    for det in detections:
        cls      = det['class']
        hazard   = det['hazard']
        box      = det['box']
        mask_img = det['mask_img']
        conf     = det['conf']
        color    = COLORS.get(cls, (255, 255, 255))

        # Semi-transparent segmentation mask fill
        if mask_img is not None:
            colored_mask = np.zeros_like(frame)
            colored_mask[mask_img > 0.5] = color
            overlay = cv2.addWeighted(overlay, 1.0, colored_mask, 0.4, 0)

        # Bounding box
        x1, y1, x2, y2 = [int(v) for v in box]
        cv2.rectangle(overlay, (x1, y1), (x2, y2), color, 2)

        # Label — material + confidence only (no pixel-estimated weight)
        if hazard:
            label    = f"! HAZARDOUS — {cls.upper()} ({int(conf * 100)}%)"
            bg_color = (0, 0, 180)
        else:
            price = PRICE_PER_KG.get(cls, 0)
            label    = f"{cls}  {int(conf * 100)}%  |  ₹{price}/kg (weight @ pickup)"
            bg_color = (30, 30, 30)

        (tw, th), _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.55, 1)
        label_y = max(y1, th + 10)
        cv2.rectangle(overlay, (x1, label_y - th - 8), (x1 + tw + 6, label_y), bg_color, -1)
        cv2.putText(overlay, label, (x1 + 3, label_y - 4),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 1, cv2.LINE_AA)

    return overlay


# ── RUN A SINGLE SCAN ─────────────────────────────────────────────────────────
def run_scan(model, db, frame):
    """
    Run YOLOv11-seg inference on one frame.
    Returns: (detections, hazard_found)
    NOTE: No weight estimation — that happens at pickup via kabadiwalla's scale.
    """
    results = model(frame, conf=CONF_THRESHOLD, verbose=False)[0]

    detections   = []
    hazard_found = False

    if results.masks is None or len(results.boxes) == 0:
        return detections, hazard_found

    h, w = frame.shape[:2]

    for mask_tensor, cls_id, conf, box in zip(
        results.masks.data,
        results.boxes.cls,
        results.boxes.conf,
        results.boxes.xyxy
    ):
        cls_idx = int(cls_id)
        if cls_idx >= len(CLASSES):
            continue
        cls  = CLASSES[cls_idx]
        conf = round(float(conf), 3)

        mask_np      = mask_tensor.cpu().numpy()
        mask_resized = cv2.resize(mask_np, (w, h), interpolation=cv2.INTER_NEAREST)
        hazard       = cls in HAZARDOUS

        detections.append({
            'class':    cls,
            'hazard':   hazard,
            'box':      box.cpu().numpy(),
            'mask_img': mask_resized,
            'conf':     conf,
        })

        if hazard:
            dropoff = EWASTE_DROPOFFS[0]  # nearest (hardcoded for demo)
            print(f"\n  ‼  {cls.upper()} — HAZARDOUS  (conf {conf})")
            print(f"     ⚠  Do NOT put in regular scrap bin.")
            print(f"     📍 Nearest certified drop-off:")
            print(f"        {dropoff['name']}")
            print(f"        {dropoff['address']}")
            print(f"        ☎  {dropoff['phone']}")
            push_alert(db, f"Hazardous item detected: {cls} (conf {conf})", is_hazard=True)
            push_scan(db, cls, conf)
            hazard_found = True
        else:
            price = PRICE_PER_KG.get(cls, 0)
            print(f"  ✓  {cls:12}  conf={conf}  |  ₹{price}/kg  (weight confirmed at pickup)")
            push_scan(db, cls, conf)

    return detections, hazard_found


# ── MAIN CAMERA LOOP ──────────────────────────────────────────────────────────
def run_camera(model, db):
    cap = cv2.VideoCapture(0)

    if not cap.isOpened():
        print("❌ Camera not found. Check connection / index.")
        return

    cap.set(cv2.CAP_PROP_FRAME_WIDTH,  FRAME_WIDTH)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, FRAME_HEIGHT)

    # Create window ONCE outside the loop so resizeWindow works
    cv2.namedWindow(WINDOW_NAME, cv2.WINDOW_NORMAL)
    cv2.resizeWindow(WINDOW_NAME, FRAME_WIDTH, FRAME_HEIGHT)

    print("\n" + "=" * 55)
    print("  KabadiAI Live Scanner  —  YOLOv11-seg")
    print("=" * 55)
    print(f"  Classes : {CLASSES}")
    print(f"  Conf    : {CONF_THRESHOLD}")
    print(f"  Cooldown: {SCAN_COOLDOWN}s between scans")
    print("─" * 55)
    print("  SPACE → scan current frame   |   Q → quit")
    print("=" * 55 + "\n")

    last_scan_time      = 0.0
    last_result_frame   = None
    result_display_until = 0.0

    while True:
        ret, frame = cap.read()
        if not ret:
            print("❌ Failed to read from camera.")
            break

        now = time.time()

        # Show scan result overlay for 3s; otherwise show live feed
        if last_result_frame is not None and now < result_display_until:
            display = last_result_frame
        else:
            display = frame.copy()
            cv2.putText(display, "KabadiAI Scanner",
                        (20, 40), cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 255, 100), 2, cv2.LINE_AA)
            cv2.putText(display, "Press SPACE to scan | Q to quit",
                        (20, 75), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (200, 200, 200), 1, cv2.LINE_AA)

            cooldown_left = SCAN_COOLDOWN - (now - last_scan_time)
            if cooldown_left > 0:
                cv2.putText(display, f"Cooldown: {cooldown_left:.1f}s",
                            (20, 105), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 200, 255), 1, cv2.LINE_AA)

        cv2.imshow(WINDOW_NAME, display)

        key = cv2.waitKey(1) & 0xFF

        if key == ord(' '):
            if now - last_scan_time < SCAN_COOLDOWN:
                remaining = round(SCAN_COOLDOWN - (now - last_scan_time), 1)
                print(f"  ⏳ Cooldown: {remaining}s remaining")
                continue

            last_scan_time = now
            print("\n🔍 Scanning...")

            detections, hazard_found = run_scan(model, db, frame)

            if detections:
                classes_found = [d['class'] for d in detections]
                print(f"\n  ✅ {len(detections)} item(s) detected: {classes_found}")
                if hazard_found:
                    print("  ‼  Hazardous item(s) found — see drop-off info above")
                print("  📡 Pushed to Firebase — check dashboard\n")

                last_result_frame    = draw_overlay(frame.copy(), detections)
                result_display_until = time.time() + 3.0
            else:
                print("  ⚠  No waste items detected — move closer or improve lighting\n")
                last_result_frame = None

        elif key == ord('q'):
            print("\nScanner closed.")
            break

    cap.release()
    cv2.destroyAllWindows()


# ── MAIN ──────────────────────────────────────────────────────────────────────
def main():
    db = init_firebase()
    print("✅ Firebase connected")

    model = YOLO(MODEL_PATH)
    print("✅ KabadiAI model loaded")
    print(f"   Classes ({len(CLASSES)}): {CLASSES}")

    run_camera(model, db)


if __name__ == "__main__":
    main()