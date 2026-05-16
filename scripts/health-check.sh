#!/bin/bash

PASS=0
FAIL=0

log() {
  echo "[$(date '+%H:%M:%S')] $1"
}

check() {
    NAME=$1
    CMD=$2

    if eval "$CMD" > /dev/null 2>&1; then
        echo " ✅ $NAME"
        PASS=$((PASS + 1))
    else
        echo " ❌ $NAME"
        FAIL=$((FAIL + 1))
    fi
}

extract_metric() {
  url=$1
  metric=$2

  curl -s "$url" | awk -v m="$metric" '$1 == m {print $2}' | head -n 1
}

log "Checking service health..."

echo "Checking containers..."
docker compose ps

check "ingestion /health" "curl -sf http://localhost:8000/health"
check "ingestion /metrics" "curl -sf http://localhost:9100/metrics"
check "validation /metrics" "curl -sf http://localhost:9101/metrics"
check "processing /metrics" "curl -sf http://localhost:9102/metrics"

# Check if system is processing data ---
RECEIVED=$(extract_metric "http://localhost:9100/metrics" "transactions_received_total")
VALIDATED=$(extract_metric "http://localhost:9101/metrics" "transactions_validated_total")
APPROVED=$(extract_metric "http://localhost:9102/metrics" "transactions_approved_total")

RECEIVED=${RECEIVED:-0}
VALIDATED=${VALIDATED:-0}
APPROVED=${APPROVED:-0}

log "Current activity: Received=$RECEIVED | Validated=$VALIDATED | Approved=$APPROVED"

if [ "$RECEIVED" -gt 0 ] || [ "$VALIDATED" -gt 0 ] || [ "$APPROVED" -gt 0 ]; then
  log "System is actively processing transactions"
else
  log "System is up but no activity detected yet"
fi

log "Health check passed"