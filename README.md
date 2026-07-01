# ♻️ KabadiAI

KabadiAI is an AI-powered waste management platform built for the Samsung Innovate Hackathon. It connects households, local scrap collectors (*kabadiwallas*), and municipal authorities to make recycling easier and more efficient.

## ✨ What it does

1. **Household App (Flutter):** Users can scan their waste using their phone camera. The AI (YOLOv11) instantly identifies if it's plastic, metal, paper, etc., and shows them the current market rate (₹/kg).
2. **Kabadiwalla Map:** Users can see nearby scrap collectors on a live map, complete with ratings and daily pickup stats.
3. **Hazard Routing:** If someone scans dangerous electronic waste (like batteries), the app automatically routes them to the nearest certified e-waste drop-off.
4. **City Dashboard (Streamlit):** A live map and dashboard for the city to see what materials are being recycled where.

## 🛠️ Built With

- **AI Model:** YOLOv11 (Ultralytics) for real-time object segmentation
- **Backend:** Python + FastAPI
- **Database:** Firebase Firestore
- **Mobile App:** Flutter
- **Dashboard:** Streamlit + Folium Maps

## 🚀 How to Run it Locally

### 1. Setup the Backend & Database Simulator
```bash
# Create and activate virtual environment
python -m venv kabadiai_env
source kabadiai_env/bin/activate

# Install requirements
pip install -r backend/requirements.txt
pip install ultralytics streamlit firebase-admin

# Start the FastAPI Server (Terminal 1)
cd backend
uvicorn main:app --reload --port 8000

# Seed the Firebase Data (Terminal 2)
cd Frontend
python simulator.py --seed-only
```

### 2. Start the City Dashboard
```bash
# Terminal 3
source kabadiai_env/bin/activate
cd Frontend
streamlit run dashboard.py
```

### 3. Run the Mobile App
```bash
# Terminal 4
cd kabadiai_app
flutter pub get
flutter run -d linux
```
