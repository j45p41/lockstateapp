#!/usr/bin/env bash
set -euo pipefail
# ────────────────────────────────────────────────────────────────
FB_UID="6ue1XtW8cndXJQyHydNo86PW1p43"          # ← your Firebase UID
REST_API_ID="ayb2a2m447"
REGION="eu-west-1"
# ────────────────────────────────────────────────────────────────
API="https://${REST_API_ID}.execute-api.${REGION}.amazonaws.com/prod"
REDIRECT="https://layla.amazon.com/api/skill/link/amzn1.ask.skill.89751fb9-1b7f-4c40-8c9f-a5231bdb3998"

echo "🔗 1) /alexaAuth redirect"
STATE=$(
  curl -sD - -o /dev/null -G \
    --data-urlencode uid="$FB_UID" \
    --data-urlencode redirect_uri="$REDIRECT" \
    "$API/alexaAuth" |
  tr -d '\r' | awk -F'state=' '/^location:/ {print $2}'
)
echo "   STATE=$STATE"; [[ -n "$STATE" ]] || { echo "❌ no state"; exit 1; }

echo -e "\n🎫 2) /alexaCallback → auth-code"
AUTH_CODE=$(
  curl -sD - -o /dev/null -G \
    --data-urlencode code=poke \
    --data-urlencode state="$STATE" \
    "$API/alexaCallback" |
  tr -d '\r' | awk -F'code=' '/^location:/ {print $2}' | cut -d'&' -f1
)
echo "   AUTH_CODE=$AUTH_CODE"; [[ -n "$AUTH_CODE" ]] || { echo "❌ no code"; exit 1; }

echo -e "\n🔑 3) /alexaToken exchange"
TOKEN_JSON=$(curl -s -X POST "$API/alexaToken" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode grant_type=authorization_code \
  --data-urlencode code="$AUTH_CODE" \
  --data-urlencode state="$STATE")
echo "   $TOKEN_JSON"
ACCESS_TOKEN=$(echo "$TOKEN_JSON" | jq -r .access_token)
[[ "$ACCESS_TOKEN" == "$FB_UID" ]] || { echo "❌ token mismatch"; exit 1; }

echo -e "\n🏠 4) /smart-home Discovery"
curl -s -X POST "$API/smart-home" \
  -H "Content-Type: application/json" \
  -d '{
        "directive":{
          "header":{"namespace":"Alexa.Discovery","name":"Discover","payloadVersion":"3","messageId":"smoke-002"},
          "payload":{"scope":{"type":"BearerToken","token":"'"$ACCESS_TOKEN"'" }}
        }
      }' | jq .

echo -e "\n✅ smoke test finished"
