""
app.py — GRID-PAY live dashboard.

Run locally:
    streamlit run app.py

Deploy free:
    Push this repo to GitHub, then deploy on https://share.streamlit.io
    (Streamlit Community Cloud) pointing at app.py. Add GROQ_API_KEY
    under App settings -> Secrets if you want live LLM-written alerts
    (optional — the app works fine without it, using template alerts).
"""

import time
import pandas as pd
import streamlit as st

import db
import bots
import simulator

st.set_page_config(page_title="GRID-PAY", layout="wide")

# ---------------------------------------------------------------------------
# One-time setup
# ---------------------------------------------------------------------------
if "initialized" not in st.session_state:
    db.init_db(reset=True)
    st.session_state.initialized = True
    st.session_state.running = False
    st.session_state.tick = 0
    st.session_state.recent_log = []

st.title("GRID-PAY — Intelligent P2P Renewable Energy Settlement")
st.caption("Autonomous RPA pipeline for micro-settling residential rooftop solar. "
           "All data below is simulated (no real meters or bank accounts involved).")

# ---------------------------------------------------------------------------
# Sidebar controls
# ---------------------------------------------------------------------------
with st.sidebar:
    st.header("Simulation controls")
    batch_size = st.slider("Readings per tick", 1, 20, 6)
    reconcile_every = st.slider("Reconcile every N ticks", 5, 50, 15)
    grid_supply = st.slider("Grid supply (kWh, this tick)", 10, 200, 50)
    grid_demand = st.slider("Grid demand (kWh, this tick)", 10, 200, 65)

    col_a, col_b = st.columns(2)
    if col_a.button("▶ Start", use_container_width=True):
        st.session_state.running = True
    if col_b.button("⏸ Pause", use_container_width=True):
        st.session_state.running = False

    if st.button("Reset everything", use_container_width=True):
        db.init_db(reset=True)
        st.session_state.tick = 0
        st.session_state.recent_log = []
        st.rerun()

    st.divider()
    st.caption("Optional: set a free Groq API key as GROQ_API_KEY in "
               "Streamlit secrets to get LLM-written tampering alerts. "
               "Without it, a clear template message is used instead.")

# ---------------------------------------------------------------------------
# Run one simulation tick
# ---------------------------------------------------------------------------
if st.session_state.running:
    st.session_state.tick += 1
    batch = simulator.generate_batch(batch_size=batch_size)
    for raw in batch:
        result = bots.run_pipeline_step(raw, grid_supply_kwh=grid_supply, grid_demand_kwh=grid_demand)
        st.session_state.recent_log = (result["log"] + st.session_state.recent_log)[:40]

    if st.session_state.tick % reconcile_every == 0:
        bots.run_reconciliation_sweep(f"tick-{st.session_state.tick - reconcile_every}",
                                       f"tick-{st.session_state.tick}")

# ---------------------------------------------------------------------------
# Top metrics
# ---------------------------------------------------------------------------
metrics = db.get_summary_metrics()
m1, m2, m3, m4, m5 = st.columns(5)
m1.metric("Transactions settled", metrics["total_transactions"])
m2.metric("Total payouts (₹)", f"{metrics['total_payout']:,}")
m3.metric("Clean energy settled (kWh)", metrics["total_clean_kwh"])
m4.metric("Open HITL alerts", metrics["open_alerts"], delta_color="inverse")
m5.metric("Ledger variances flagged", metrics["flagged_ledger_entries"])

st.divider()

# ---------------------------------------------------------------------------
# Charts
# ---------------------------------------------------------------------------
left, right = st.columns([2, 1])

with left:
    st.subheader("Tariff rate over recent transactions")
    tx = db.fetch_all("transactions", limit=200)
    if tx:
        tx_df = pd.DataFrame(tx).sort_values("id")
        st.line_chart(tx_df.set_index("id")["tariff_rate"])
    else:
        st.info("Press Start in the sidebar to begin settling transactions.")

    st.subheader("Payout per meter")
    wallets = db.get_wallet_balances()
    if wallets:
        w_df = pd.DataFrame(wallets)
        st.bar_chart(w_df.set_index("meter_id")["balance"])

with right:
    st.subheader("HITL guardrail alerts")
    alerts = db.fetch_all("alerts", limit=15)
    if alerts:
        for a in alerts:
            st.warning(f"**{a['meter_id']}** — {a['message']}", icon="⚠️")
    else:
        st.success("No tampering-pattern alerts raised yet.")

st.divider()

st.subheader("Live agent log")
log_box = st.container(height=220)
with log_box:
    for line in st.session_state.recent_log:
        st.text(line)

st.subheader("Ledger reconciliation (reported vs ingested per meter)")
ledger = db.fetch_all("ledger", limit=20)
if ledger:
    st.dataframe(pd.DataFrame(ledger), use_container_width=True, hide_index=True)
else:
    st.caption("Runs automatically every few ticks — increase 'Reconcile every N ticks' speed if needed.")

# ---------------------------------------------------------------------------
# Keep the loop going while "running" is on
# ---------------------------------------------------------------------------
if st.session_state.running:
    time.sleep(1.0)
    st.rerun()
