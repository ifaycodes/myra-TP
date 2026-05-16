import logging
import time
import uuid
import redis
import json
from fastapi import FastAPI, HTTPException
from fastapi.responses import Response, JSONResponse
from pydantic import BaseModel
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST, start_http_server

# -- Logging ------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  level=%(levelname)s  msg=%(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
logger = logging.getLogger("ingestion")

# -- Prometheus Metrics -------------------------------------------------------
TRANSACTIONS_RECEIVED = Counter(
    "transactions_received_total",
    "Total transaction requests received",
)
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "Request latency",
    ["endpoint"],
    buckets=[0.01, 0.05, 0.1, 0.25, 0.5, 1.0],
)
APP_UP = Gauge("ingestion_up", "Whether ingestion service is running")
APP_UP.set(1)

start_http_server(9100)

# -- Redis --------------------------------------------------------------------
r = redis.Redis(host="redis", port=6379, decode_responses=True)

# -- App ----------------------------------------------------------------------
app = FastAPI()

class Transaction(BaseModel):
    amount: float
    currency: str
    sender: str
    receiver: str

@app.post("/transaction", status_code=202)
def receive_transaction(tx: Transaction):
    start = time.time()

    tx_data = tx.model_dump()
    tx_data["id"] = str(uuid.uuid4())

    r.lpush("queue:ingest", json.dumps(tx_data))
    TRANSACTIONS_RECEIVED.inc()

    logger.info("tx_id=%s action=received sender=%s amount=%s %s",
                tx_data["id"], tx.sender, tx.amount, tx.currency)

    REQUEST_LATENCY.labels(endpoint="/transaction").observe(time.time() - start)
    return {"status": "accepted", "tx_id": tx_data["id"]}

@app.get("/health")
def health():
    return {"status": "healthy"}

@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)