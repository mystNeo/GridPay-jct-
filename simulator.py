"""
simulator.py — stands in for real rooftop-solar smart meters.

Since you don't have real IoT hardware for the hackathon, this generates
realistic-looking readings for a fleet of meters, including the messy
edge cases the problem statement calls out:
  - dropped / malformed readings (simulates network disconnects)
  - duplicate timestamps (simulates retried transmissions)
  - occasional generation spikes (simulates meter tampering)

Call generate_batch() once per "tick" from the app to get a list of raw
readings, then feed each one into bots.ingestion_bot().
"""

import random
from datetime import datetime, timezone

METER_IDS = [f"METER-{i:03d}" for i in range(1, 11)]  # 10 rooftop producers

# Rough per-meter baseline so tampering spikes are easy to detect later
_BASELINES = {m: round(random.uniform(1.5, 4.5), 2) for m in METER_IDS}


def _now():
    return datetime.now(timezone.utc).isoformat()


def _normal_reading(meter_id: str) -> dict:
    base = _BASELINES[meter_id]
    generated = max(0.0, round(random.gauss(base, base * 0.15), 3))
    consumed = max(0.0, round(random.gauss(base * 0.6, base * 0.2), 3))
    return {
        "meter_id": meter_id,
        "ts": _now(),
        "kwh_generated": generated,
        "kwh_consumed": consumed,
    }


def generate_batch(batch_size: int = 10, anomaly_rate: float = 0.06, dropout_rate: float = 0.08) -> list[dict]:
    """
    Returns a list of RAW readings, some of which are intentionally broken.
    Each item also carries a "_sim_status" hint of what kind of chaos was
    injected, purely so the ingestion bot has ground truth to validate against.
    """
    batch = []
    for _ in range(batch_size):
        meter_id = random.choice(METER_IDS)
        reading = _normal_reading(meter_id)
        roll = random.random()

        if roll < dropout_rate:
            # Simulate a dropped/incomplete packet from a flaky endpoint
            reading["kwh_generated"] = None
            reading["_sim_status"] = "dropped"

        elif roll < dropout_rate + anomaly_rate:
            # Simulate meter tampering: an implausible generation spike
            reading["kwh_generated"] = round(reading["kwh_generated"] * random.uniform(3.5, 6), 3)
            reading["_sim_status"] = "tamper_spike"

        elif roll < dropout_rate + anomaly_rate + 0.05:
            # Simulate a duplicate/retried transmission
            reading["_sim_status"] = "duplicate"
        else:
            reading["_sim_status"] = "ok"

        batch.append(reading)
    return batch


if __name__ == "__main__":
    for r in generate_batch(5):
        print(r)
