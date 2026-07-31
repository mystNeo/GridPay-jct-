# GridPay-jct-
An AI + IoT based GenAI model. 
<img width="1917" height="901" alt="Screenshot 2026-07-31 191633" src="https://github.com/user-attachments/assets/facd535d-7b85-410c-9995-4fd7bd839fb1" />

# GRID-PAY — Intelligent Automation for P2P Renewable Energy Settlement

Hackathon MVP for problem statement **SDGIAP006**. Simulates a fleet of
rooftop-solar smart meters and runs their micro-settlements through an
autonomous RPA pipeline — no real hardware, banks, or paid APIs required.

## What's inside

| File | Role |
|---|---|
| `simulator.py` | Fakes IoT smart-meter telemetry, including dropped packets, duplicates, and tampering spikes |
| `db.py` | SQLite schema + helpers (readings, transactions, ledger, alerts, wallets) |
| `bots.py` | The four specialist agents + HITL guardrail from the problem statement |
| `llm_utils.py` | Turns a detected anomaly into a human-readable alert (Groq API, free tier — optional) |
| `app.py` | Streamlit live dashboard tying it all together |

### The pipeline, matched to the problem statement

1. **Meter Telemetry Ingestion Bot** (`bots.ingestion_bot`) — validates each
   reading, drops/dedupes bad ones instead of crashing.
2. **Dynamic Tariff Calculation Agent** (`bots.tariff_agent`) — prices each
   reading off a simple supply/demand curve.
3. **Financial Settlement RPA** (`bots.settlement_rpa`) — pays a mock wallet
   and logs a payment reference ID.
4. **Utility Ledger Reconciliation Bot** (`bots.reconciliation_bot`) —
   compares reported vs ingested kWh per meter and flags variance.
5. **HITL guardrail** (`bots.hitl_check`) — pauses payout and raises an
   alert if a meter's reading is a wild outlier vs its own history
   (the "meter tampering" case in the problem statement).

## Run it locally

```bash
pip install -r requirements.txt
streamlit run app.py
```

Open the local URL Streamlit prints, click **Start** in the sidebar, and
watch transactions, payouts, and alerts populate live.

## Optional: real LLM-written alerts

By default, HITL alerts use a clear template message — the app works
fully without any API key. To get an LLM to write the alert text instead:

1. Get a **free** API key at https://console.groq.com
2. Set it as an environment variable before running locally:
   ```bash
   export GROQ_API_KEY=your_key_here
   streamlit run app.py
   ```
   (On Windows: `set GROQ_API_KEY=your_key_here`)

## Deploy for free

**Streamlit Community Cloud** (recommended — one deploy, no server to manage):

1. Push this folder to a public GitHub repo.
2. Go to https://share.streamlit.io, sign in with GitHub.
3. Click "New app", pick the repo and `app.py` as the entry point.
4. (Optional) Under "Advanced settings → Secrets", add:
   ```
   GROQ_API_KEY = "your_key_here"
   ```
5. Deploy. You'll get a free public `*.streamlit.app` URL to demo with.
