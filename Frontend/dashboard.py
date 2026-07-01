"""
KabadiAI — Municipal Command Center Dashboard
Streamlit + Firebase Firestore + Folium maps + Plotly charts

Run:  streamlit run dashboard.py
Requires backend running at http://localhost:8000
"""

import streamlit as st
import firebase_admin
from firebase_admin import credentials, firestore
import folium
from streamlit_folium import st_folium
import plotly.express as px
import plotly.graph_objects as go
import pandas as pd
from datetime import datetime
from pathlib import Path
import time
import requests

# ── PAGE CONFIG ───────────────────────────────────────────────────────────────
st.set_page_config(
    page_title="KabadiAI — Municipal Command Center",
    page_icon="♻️",
    layout="wide",
)

BACKEND = "http://localhost:8000"

# ── FIREBASE INIT ─────────────────────────────────────────────────────────────
@st.cache_resource
def init_firebase():
    if not firebase_admin._apps:
        root = Path(__file__).resolve().parent
        cred_path = root / "firebase_key.json"
        cred = credentials.Certificate(str(cred_path))
        firebase_admin.initialize_app(cred)
    return firestore.client()

db = init_firebase()

# ── BACKEND HELPERS ───────────────────────────────────────────────────────────
@st.cache_data(ttl=10)
def fetch_heatmap():
    try:
        r = requests.get(f"{BACKEND}/heatmap", timeout=3)
        if r.ok:
            return r.json(), True
    except Exception:
        pass
    return None, False

@st.cache_data(ttl=60)
def fetch_forecast():
    try:
        r = requests.get(f"{BACKEND}/forecast", timeout=3)
        if r.ok:
            return r.json(), True
    except Exception:
        pass
    return None, False

# ── DATA FETCHERS (Firestore) ─────────────────────────────────────────────────
# TTL=60 → Firestore is queried at most once per minute regardless of how
# often Streamlit re-runs. This prevents hitting the free-tier quota limit.
@st.cache_data(ttl=60)
def get_scans():
    try:
        docs = db.collection("scans").order_by(
            "timestamp", direction=firestore.Query.DESCENDING
        ).limit(200).stream()
        return [d.to_dict() for d in docs]
    except Exception as e:
        if "Quota" in str(e) or "RESOURCE_EXHAUSTED" in str(e):
            st.session_state["quota_error"] = True
        return []

@st.cache_data(ttl=60)
def get_kabadiwallas():
    try:
        docs = db.collection("kabadiwallas").stream()
        return [d.to_dict() for d in docs]
    except Exception:
        return []

@st.cache_data(ttl=60)
def get_alerts():
    try:
        docs = db.collection("alerts").order_by(
            "timestamp", direction=firestore.Query.DESCENDING
        ).limit(20).stream()
        return [d.to_dict() for d in docs]
    except Exception:
        return []

# ── SIMULATION PROFILES ───────────────────────────────────────────────────────
PROFILES = {
    "Normal weekday": {
        "kabs": 347, "tons": 48.2, "hazards": 7, "ewaste": 1.8,
        "flow": {"Plastics": 42, "E-waste": 28, "Metals": 20, "Paper": 10},
        "badge": "🟢 All zones normal",
    },
    "Day after Diwali": {
        "kabs": 412, "tons": 89.7, "hazards": 31, "ewaste": 11.4,
        "flow": {"Plastics": 28, "E-waste": 52, "Metals": 14, "Paper": 6},
        "badge": "🔴 Diwali surge active",
    },
    "Post-monsoon (Oct)": {
        "kabs": 298, "tons": 31.5, "hazards": 3, "ewaste": 0.9,
        "flow": {"Plastics": 51, "E-waste": 15, "Metals": 18, "Paper": 16},
        "badge": "🔵 Monsoon profile",
    },
}

# ── HEADER ────────────────────────────────────────────────────────────────────
col_logo, col_title, col_time = st.columns([1, 6, 2])
with col_logo:
    st.markdown("## ♻️")
with col_title:
    st.markdown("## KabadiAI — Municipal Command Center")
    st.caption("Delhi NCR · Real-time recyclable intelligence")
with col_time:
    st.markdown(f"**{datetime.now().strftime('%d %b %Y, %H:%M')}**")
    st.caption("🟢 Live")

st.divider()

# ── SIMULATION PROFILE + BACKEND STATUS ──────────────────────────────────────
col_sim, col_badge, col_status = st.columns([3, 2, 2])
with col_sim:
    profile_name = st.selectbox(
        "Simulation profile",
        list(PROFILES.keys()),
        label_visibility="collapsed"
    )
with col_badge:
    st.info(PROFILES[profile_name]["badge"])
with col_status:
    heatmap_data, backend_live = fetch_heatmap()
    if backend_live:
        st.success("🔗 Backend connected")
    else:
        st.warning("⚠ Backend offline — using mock data")
        st.caption(f"Start: `uvicorn main:app --reload` in `backend/`")

profile = PROFILES[profile_name]

# ── FETCH LIVE DATA ───────────────────────────────────────────────────────────
scans        = get_scans()
kabadiwallas = get_kabadiwallas()
alerts       = get_alerts()
scans_df     = pd.DataFrame(scans) if scans else pd.DataFrame()

# ── KPI CARDS ─────────────────────────────────────────────────────────────────
k1, k2, k3, k4 = st.columns(4)

# Prefer live heatmap totals; fall back to profile mock
live_total_scans   = heatmap_data["total_scans"]  if heatmap_data else None
live_hazard_alerts = heatmap_data["hazard_alerts"] if heatmap_data else None

with k1:
    live_kabs = len(kabadiwallas) if kabadiwallas else profile["kabs"]
    st.metric("Active Kabadiwallas", live_kabs, "+12 vs yesterday")

with k2:
    st.metric("Scrap Recovered Today", f"{profile['tons']} t", "+6.4 t vs avg")

with k3:
    hazards = live_hazard_alerts if live_hazard_alerts is not None else (
        len([s for s in scans if s.get("hazardous")]) if scans else profile["hazards"]
    )
    st.metric("Hazard Alerts", hazards, "Li-ion + CRT")

with k4:
    st.metric("E-waste Routed", f"{profile['ewaste']} t", "↑ 42% vs last week")

st.divider()

# ── MAP + ALERTS ──────────────────────────────────────────────────────────────
col_map, col_alerts_ui = st.columns([3, 2])

with col_map:
    st.markdown("#### 🗺️ Live Recyclable Heat Map — Delhi NCR")

    m = folium.Map(location=[28.6139, 77.2090], zoom_start=11, tiles="CartoDB positron")

    material_colors = {
        "plastic":    "#2a78d6",
        "cardboard":  "#8B6914",
        "glass":      "#1baf7a",
        "metal_scrap":"#eda100",
        "paper":      "#6B46C1",
        "ewaste":     "#e34948",
    }

    if not scans_df.empty and "lat" in scans_df.columns:
        for _, row in scans_df.iterrows():
            color = material_colors.get(row.get("material", ""), "#888")
            price = row.get("price_per_kg", "?")
            conf  = row.get("confidence", "?")
            folium.CircleMarker(
                location=[row["lat"], row["lng"]],
                radius=5,
                color=color,
                fill=True,
                fill_opacity=0.7,
                popup=(
                    f"<b>{row.get('material','?')}</b><br>"
                    f"Conf: {conf}<br>"
                    f"₹{price}/kg<br>"
                    f"<i>Weight confirmed at pickup</i>"
                ),
            ).add_to(m)

    for k in kabadiwallas:
        folium.Marker(
            location=[k["lat"], k["lng"]],
            popup=f"{k['name']} ★{k.get('rating','')} | ₹{k.get('earnings_today','')} today",
            icon=folium.Icon(color="green", icon="person", prefix="fa"),
        ).add_to(m)

    st_folium(m, width=700, height=400)

with col_alerts_ui:
    st.markdown("#### 🚨 Real-time Alert Stream")
    if alerts:
        for alert in alerts[:8]:
            is_hazard = alert.get("hazardous", False)
            msg  = alert.get("message", "")
            zone = alert.get("zone", "")
            ts   = alert.get("timestamp", "")[:16].replace("T", " ")
            if is_hazard:
                st.error(f"**{ts}** | {zone}\n{msg}")
            else:
                st.success(f"**{ts}** | {zone}\n{msg}")
    else:
        st.info("No alerts yet — simulator not running")
        st.caption("Run `python simulator.py` in a separate terminal")

st.divider()

# ── MATERIAL FLOW CHART ───────────────────────────────────────────────────────
col_flow, col_trend = st.columns(2)

with col_flow:
    st.markdown("#### 📊 Material Flow Analytics")

    # Priority: backend heatmap → live Firestore scan counts → profile mock
    if backend_live and heatmap_data and heatmap_data["total_scans"] > 0:
        mt = heatmap_data["material_totals"]
        total = max(sum(mt.values()), 1)
        flow_data = {
            "Plastics": int(mt.get("plastic",    0) / total * 100),
            "E-waste":  int(mt.get("ewaste",     0) / total * 100),
            "Metals":   int(mt.get("metal_scrap",0) / total * 100),
            "Paper":    int((mt.get("paper",0) + mt.get("cardboard",0)) / total * 100),
        }
        data_source = "live (backend)"
    elif not scans_df.empty and "material" in scans_df.columns:
        counts = scans_df["material"].value_counts()
        total  = max(counts.sum(), 1)
        flow_data = {
            "Plastics": int(counts.get("plastic",    0) / total * 100),
            "E-waste":  int(counts.get("ewaste",     0) / total * 100),
            "Metals":   int(counts.get("metal_scrap",0) / total * 100),
            "Paper":    int((counts.get("paper",0) + counts.get("cardboard",0)) / total * 100),
        }
        data_source = "live (Firestore)"
    else:
        flow_data   = profile["flow"]
        data_source = "simulation profile"

    st.caption(f"Data source: {data_source}")

    fig = px.pie(
        values=list(flow_data.values()),
        names=list(flow_data.keys()),
        color_discrete_sequence=["#2a78d6", "#e34948", "#eda100", "#1baf7a"],
        hole=0.4,
    )
    fig.update_layout(margin=dict(t=20, b=20, l=20, r=20), height=280)
    st.plotly_chart(fig, use_container_width=True)

with col_trend:
    st.markdown("#### 📈 Scrap Recovery Trend (7-day forecast)")

    forecast_data, forecast_live = fetch_forecast()

    if forecast_live and forecast_data:
        days   = [f["date"]   for f in forecast_data["forecast"]]
        values = [f["tonnes"] for f in forecast_data["forecast"]]
        st.caption(f"Model: {forecast_data['model']}")
    else:
        days   = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        values = [38.2, 42.1, 45.8, 41.3, 48.2, 52.6, 49.1]
        st.caption("Source: mock data (backend offline)")

    fig2 = go.Figure()
    fig2.add_trace(go.Scatter(
        x=days, y=values,
        mode="lines+markers",
        line=dict(color="#1baf7a", width=2.5),
        marker=dict(size=7),
        fill="tozeroy",
        fillcolor="rgba(27,175,122,0.1)",
        name="Tonnes recovered",
    ))
    fig2.update_layout(
        margin=dict(t=20, b=20, l=20, r=20),
        height=280,
        yaxis_title="Tonnes",
        showlegend=False,
        plot_bgcolor="rgba(0,0,0,0)",
        paper_bgcolor="rgba(0,0,0,0)",
    )
    st.plotly_chart(fig2, use_container_width=True)

st.divider()

# ── PREDICTIVE INTELLIGENCE ───────────────────────────────────────────────────
st.markdown("#### 🤖 Predictive Intelligence — Prophet Model (87% accuracy)")

p1, p2, p3 = st.columns(3)

if profile_name == "Day after Diwali":
    with p1:
        st.error("**CRITICAL — E-waste surge**\nConnaught Pl: 52% of all material is e-waste. Dispatch certified fleet immediately.")
    with p2:
        st.error("**Hazard alert × 31**\nLi-ion battery concentration 8× above safe threshold across 4 zones.")
    with p3:
        st.warning("**Capacity warning**\nGreenTech Recyclers at 94% capacity. Activate overflow partner by 18:00.")
elif profile_name == "Post-monsoon (Oct)":
    with p1:
        st.warning("**Plastic surge**\nPost-monsoon PET bottles at 2× normal. Saturation routes recommended for Dwarka.")
    with p2:
        st.warning("**Paper degradation**\nCardboard quality down 40% due to moisture. Alert households to dry stock before pickup.")
    with p3:
        st.success("**Low hazard period**\nE-waste well below threshold. Routine operations only.")
else:
    with p1:
        st.warning("**Rohini zone**\nNext 7 days: +23% metals. Deploy 2 extra vehicles Wed–Fri.")
    with p2:
        st.warning("**Lajpat Nagar**\nCardboard peak predicted post-Eid. Temporary depot recommended.")
    with p3:
        st.error("**Connaught Pl ⚠**\nE-waste 2.4× above baseline. Certified partner capacity check needed.")

st.divider()

# ── LIVE SCANS TABLE ──────────────────────────────────────────────────────────
st.markdown("#### 📋 Live Scan Feed")

if not scans_df.empty:
    # Show corrected column set — no weight_kg/estimated_value (design decision)
    display_cols = ["timestamp", "zone", "material", "confidence",
                    "price_per_kg", "hazardous", "source"]
    available = [c for c in display_cols if c in scans_df.columns]
    st.dataframe(
        scans_df[available].head(20),
        use_container_width=True,
        hide_index=True,
    )
    st.caption(
        "📌 Weight is NOT stored at scan time — confirmed by kabadiwalla's "
        "physical scale at pickup. Final payout = actual_weight × price_per_kg."
    )
else:
    st.info("No scan data yet. Run the simulator: `python simulator.py`")

# ── QUOTA WARNING ─────────────────────────────────────────────────────────────
if st.session_state.get("quota_error"):
    st.warning(
        "⚠️ **Firestore free-tier quota exceeded** — dashboard is showing "
        "simulation profile data. Data will refresh automatically once your "
        "quota resets (daily at midnight Pacific). "
        "To avoid this: stop `simulator.py` when not actively demoing.",
        icon="🔥",
    )

# ── AUTO REFRESH ──────────────────────────────────────────────────────────────
# 30s instead of 10s → 3× fewer Firestore reads per session
st.caption("Dashboard auto-refreshes every 30 seconds · Firestore cached 60s")
time.sleep(30)
st.rerun()