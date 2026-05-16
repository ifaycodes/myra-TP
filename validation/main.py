import json
import logging
import os
import time
import redis
from prometheus_client import Counter, Gauge, start_http_server

# -- Logging ------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  level=%(levelname)s  msg=%(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
logger = logging.getLogger("validation")

# -- Prometheus ---------------------------------------------------------------
TRANSACTIONS_VALIDATED = Counter(
    "transactions_validated_total",
    "Transactions that passed validation",
)
TRANSACTIONS_FAILED = Counter(
    "transactions_failed_total",
    "Transactions that failed validation",
)
APP_UP = Gauge("validation_up", "Whether validation service is running")
APP_UP.set(1)

# -- Redis --------------------------------------------------------------------
REDIS_HOST = os.getenv("REDIS_HOST", "redis")
r = redis.Redis(host=REDIS_HOST, port=6379, decode_responses=True)

# -- Validation logic ---------------------------------------------------------
ALLOWED_CURRENCIES = {"NGN", "USD", "GBP", "EUR", "GHS", "KES"}

def validate(tx: dict) -> tuple[bool, str]:
    if not tx.get("amount") or tx["amount"] <= 0:
        return False, "invalid amount"
    if tx.get("currency", "").upper() not in ALLOWED_CURRENCIES:
        return False, f"unsupported currency: {tx.get('currency')}"
    if not tx.get("sender", "").strip():
        return False, "missing sender"
    if not tx.get("receiver", "").strip():
        return False, "missing receiver"
    return True, "ok"

# -- Worker loop --------------------------------------------------------------
def run():
    logger.info("action=startup msg=validation worker running")
    while True:
        try:
            # brpop blocks and waits until a message arrives
            result = r.brpop("queue:ingest", timeout=5)
            if result is None:
                continue

            _, raw = result
            tx = json.loads(raw)
            valid, reason = validate(tx)

            if valid:
                r.lpush("queue:validated", json.dumps(tx))
                TRANSACTIONS_VALIDATED.inc()
                logger.info("tx_id=%s action=validated", tx.get("id"))
            else:
                TRANSACTIONS_FAILED.inc()
                logger.warning("tx_id=%s action=failed reason=%s", tx.get("id"), reason)

        except Exception as e:
            logger.error("action=error msg=%s", str(e))
            time.sleep(2)

if __name__ == "__main__":
    start_http_server(9101)
    run()