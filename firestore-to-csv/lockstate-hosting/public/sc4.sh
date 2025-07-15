#!/usr/bin/env bash
set -euo pipefail

# ─── CONFIG ────────────────────────────────────────────────────────────────
API="https://18glpgnilb.execute-api.eu-west-1.amazonaws.com/prod"
STATE="eyJ1aWQiOiI2dWUxWHRXOGNuZFhKUXlIeWRObzg2UFcxcDQzIiwidCI6MTc1MTkwNjcxMzMwOCwiciI6Ik81ekk5dEV3MGdZIn0.6Q_xkjYzLqhm-b1hyARKM_dwLG6YXMlXts--AdNeFCA"

echo
echo "1) Raw GET /alexaCallback?code=poke&state=… → inspect status & headers"
curl -i -G "$API/alexaCallback" \
     --data-urlencode "code=poke" \
     --data-urlencode "state=$STATE"

echo
echo "2) Find the API‐GW resource ID for /alexaCallback"
REST_API_ID="ayb2a2m447"   # your API id
REGION="eu-west-1"
CB_ID=$(
  aws apigateway get-resources \
    --rest-api-id $REST_API_ID \
    --region $REGION \
    --query "items[?path=='/alexaCallback'].id" \
    --output text
)
echo "   → /alexaCallback resource-id = $CB_ID"

echo
echo "3) Show Method configuration"
aws apigateway get-method \
  --rest-api-id $REST_API_ID \
  --resource-id  $CB_ID \
  --http-method  GET \
  --region       $REGION

echo
echo "4) Show Integration target for GET"
aws apigateway get-integration \
  --rest-api-id  $REST_API_ID \
  --resource-id   $CB_ID \
  --http-method   GET \
  --region        $REGION
