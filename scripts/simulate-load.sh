#!/bin/bash

INGESTION_URL="http://localhost:8000/transaction"
PROMETHEUS_URL="http://localhost:9100/metrics"
TOTAL=50
SUCCESS=0
FAILED=0

log() {
  echo "[$(date '+%H:%M:%S')] $1"
}

echo "==============================="
log " Sending $TOTAL transactions"

for i in $(seq 1 $TOTAL); do
    # randomise amount — some valid, some over 1 million to trigger declined
    AMOUNT=$((RANDOM * RANDOM % 10000 + 1))

    # randomise currency — include one bad one to trigger validation failure
    CURRENCIES=("NGN" "USD" "GBP" "EUR" "XYZ")
    CURRENCY=${CURRENCIES[$((RANDOM % 5))]}

    SENDER="sender_$i"
    RECEIVER="merchant_$i"

    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST $INGESTION_URL \
        -H "Content-Type: application/json" \
        -d "{\"amount\": $AMOUNT, \"currency\": \"$CURRENCY\", \"sender\": \"$SENDER\", \"receiver\": \"$RECEIVER\"}")

    if [ "$RESPONSE" -eq 202 ]; then
        SUCCESS=$((SUCCESS + 1))
    else
        FAILED=$((FAILED + 1))
    fi

    # small delay so you can watch logs in real time
    sleep 0.1
done

echo "==============================="
log "Results"
echo ""
echo " Sent:    $TOTAL"
echo " 202 OK:  $SUCCESS"
echo " Errors:  $FAILED"

# give the pipeline a few seconds to finish processing
echo ""
echo "Waiting 5s for pipeline to finish processing..."
sleep 5

# pull counts from prometheus and compare
echo ""
echo "==============================="
log "Prometheus Counts"


RECEIVED=$(curl -s $PROMETHEUS_URL | grep "^transactions_received_total " | awk '{print $2}')
VALIDATED=$(curl -s http://localhost:9101/metrics | grep "^transactions_validated_total " | awk '{print $2}')
FAILED_VAL=$(curl -s http://localhost:9101/metrics | grep "^transactions_failed_total " | awk '{print $2}')
APPROVED=$(curl -s http://localhost:9102/metrics | grep "^transactions_approved_total " | awk '{print $2}')
DECLINED=$(curl -s http://localhost:9102/metrics | grep "^transactions_declined_total " | awk '{print $2}')

echo " transactions_received_total:  ${RECEIVED:-0}"
echo " transactions_validated_total: ${VALIDATED:-0}"
echo " transactions_failed_total:    ${FAILED_VAL:-0}"
echo " transactions_approved_total:  ${APPROVED:-0}"
echo " transactions_declined_total:  ${DECLINED:-0}"

log "🎉 Full pipeline is consistent"