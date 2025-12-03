# 1. Set your URL
API_URL="https://8v3fdpqpr0.execute-api.us-east-1.amazonaws.com/ingest"

# 2. Run the loop (60 seconds * 17 reqs = ~1,020 requests)
echo "Starting 1,000 RPM load test..."
start_time=$(date +%s)

for i in {1..60}; do
    echo "Time: $(($(date +%s) - start_time))s - Sending batch of 17..."
    
    # Spawn 17 requests in parallel
    for j in {1..17}; do
        curl -X POST "$API_URL" \
             -H "Content-Type: application/json" \
             -d "{\"tenant_id\": \"chaos_test\", \"log_id\": \"batch-$i-req-$j\", \"text\": \"Sustained load test $i-$j\"}" \
             --silent --output /dev/null &
    done
    
    # Wait for the next second tick
    sleep 1
done

echo "Test Complete. Sent ~1,020 requests."
