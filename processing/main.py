import json
import logging
import os
import time
import redis
import mysql.connector
from prometheus_client import Counter, Histogram, Gauge, start_http_server

# -- Logging ------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  level=%(levelname)s  msg=%(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
logger = logging.getLogger("processing")

# -- Prometheus ---------------------------------------------------------------
PROCESSING_LATENCY = Histogram(
    "processing_latency_seconds",
    "Time taken to process each transaction",
    buckets=[0.01, 0.05, 0.1, 0.25, 0.5, 1.0],
)
TRANSACTIONS_APPROVED = Counter(
    "transactions_approved_total",
    "Transactions marked approved",
)
TRANSACTIONS_DECLINED = Counter(
    "transactions_declined_total",
    "Transactions marked declined",
)
APP_UP = Gauge("processing_up", "Whether processing service is running")
APP_UP.set(1)

# -- Redis --------------------------------------------------------------------
REDIS_HOST = os.getenv("REDIS_HOST", "redis")
r = redis.Redis(host=REDIS_HOST, port=6379, decode_responses=True)

# -- Database -----------------------------------------------------------------
def get_db():
    return mysql.connector.connect(
        host=os.getenv("DB_HOST", "db"),
        user=os.getenv("DB_USER", "user"),
        password=os.getenv("DB_PASSWORD", "password"),
        database=os.getenv("DB_NAME", "transactions"),
    )

def write_to_db(tx: dict, status: str, duration: float):
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute(
        """
        INSERT INTO transactions 
        (id, amount, currency, sender, receiver, status, processed_at)
        VALUES (%s, %s, %s, %s, %s, %s, NOW())
        """,
        (tx["id"], tx["amount"], tx["currency"],
         tx["sender"], tx["receiver"], status)
    )
    conn.commit()
    cursor.close()
    conn.close()

# -- Decision logic -----------------------------------------------------------
def decide(tx: dict) -> str:
    # simple rule: amounts over 1,000,000 are declined
    if tx["amount"] > 1_000_000:
        return "declined"
    return "approved"

# -- Worker loop --------------------------------------------------------------
def run():
    logger.info("action=startup msg=processing worker running")
    while True:
        try:
            result = r.brpop("queue:validated", timeout=5)
            if result is None:
                continue

            _, raw = result
            tx = json.loads(raw)

            start = time.time()
            status = decide(tx)
            duration = time.time() - start

            write_to_db(tx, status, duration)
            PROCESSING_LATENCY.observe(duration)

            if status == "approved":
                TRANSACTIONS_APPROVED.inc()
                logger.info("tx_id=%s action=approved amount=%s",
                            tx.get("id"), tx.get("amount"))
            else:
                TRANSACTIONS_DECLINED.inc()
                logger.warning("tx_id=%s action=declined amount=%s",
                               tx.get("id"), tx.get("amount"))

        except Exception as e:
            logger.error("action=error msg=%s", str(e))
            time.sleep(2)

if __name__ == "__main__":
    start_http_server(9102)
    run()