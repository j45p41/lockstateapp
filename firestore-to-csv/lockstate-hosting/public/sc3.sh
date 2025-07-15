#!/usr/bin/env bash
set -euo pipefail

# ─── CONFIG ─────────────────────────────────────────────────────────────────
API_ROOT="https://18glpgnilb.execute-api.eu-west-1.amazonaws.com/prod"
REDIRECT_URI="https://layla.amazon.com/api/skill/link/amzn1.ask.skill.89751fb9-1b7f-4c40-8c9f-a5231bdb3998"

FB_UID="6ue1XtW8cndXJQyHydNo86PW1p43"   # ← a real Firebase UID
EMAIL="new2@maintest.com"             # ← a real Firebase email
PASS="test123"                        # ← that account’s exact password

echo
echo "1) ACCOUNT-LINKING: Fetch 'state' from GET /alexaAuth"
STATE=$(
  curl -s -D - -o /dev/null -G \
    --data-urlencode "uid=$FB_UID" \
    --data-urlencode "redirect_uri=$REDIRECT_URI" \
    "$API_ROOT/alexaAuth" \
  | tr -d $'\r' \
  | awk -F'state=' '/^location:/ {print $2}' \
)
echo "   → STATE=$STATE"
[[ -n "$STATE" ]] || { echo "✖️  could not extract STATE"; exit 1; }

echo
echo "2) ACCOUNT-LINKING: Simulate Amazon GET → /alexaCallback (code=poke)"
AUTH_CODE=$(
  curl -s -D - -o /dev/null -G \
    --data-urlencode "code=poke" \
    --data-urlencode "state=$STATE" \
    "$API_ROOT/alexaCallback" \
  | tr -d $'\r' \
  | awk -F'code=' '/^location:/ {print $2}' \
)
echo "   → AUTH_CODE=$AUTH_CODE"
[[ -n "$AUTH_CODE" ]] || { echo "✖️  could not extract AUTH_CODE"; exit 1; }

echo
echo "3) ACCOUNT-LINKING: Exchange AUTH_CODE for token via POST /alexaToken"
curl -i -X POST "$API_ROOT/alexaToken" \
     -H 'Content-Type: application/x-www-form-urlencoded' \
     --data-urlencode "grant_type=authorization_code" \
     --data-urlencode "code=$AUTH_CODE" \
     --data-urlencode "state=$STATE" \
  | head -n 10

echo
echo "4) SMART-HOME: POST /smartHome with a dummy discovery directive"
curl -v -X POST "$API_ROOT/smartHome" \
     -H 'Content-Type: application/json' \
     -d '{
  "directive": {
    "header": {
      "namespace": "Alexa.Discovery",
      "name": "Discover",
      "messageId": "test-abc-123",
      "correlationToken": "xyz",
      "payloadVersion": "3"
    },
    "payload": {}
  }
}'
