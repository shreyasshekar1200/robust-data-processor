#!/bin/bash

# Replace this with your actual Terraform Output URL
API_URL="https://brawnrcu0e.execute-api.us-east-1.amazonaws.com/ingest"

echo "Starting 1,000 RPM Mixed Load Test (JSON + Text)..."
for i in {1..1000}; do
  if (( i % 2 == 0 )); then
     # --- Scenario 1: Structured JSON ---
     curl -X POST "$API_URL" \
          -H "Content-Type: application/json" \
          -d "{\"tenant_id\": \"acme\", \"log_id\": \"test-$i\", \"text\": \"Structured JSON Log entry $i\"}" \
          --output /dev/null &

  else
     # --- Scenario 2: Unstructured Text ---
     curl -X POST "$API_URL" \
          -H "Content-Type: text/plain" \
          -H "X-Tenant-ID: beta_inc" \
          -d "Unstructured Raw Text Log entry $i" \
          --output /dev/null &
  fi

  # 4. Rate Limiting (The "RPM")
  # We sleep for 0.06 seconds between requests.
  # Math: 1 request / 0.06 seconds = ~16.6 requests per second.
  # 16.6 reqs/sec * 60 seconds = ~1,000 requests per minute.
  sleep 0.06

done

echo "Done! 1,000 Mixed requests sent."
