#!/usr/bin/env bash
set -euo pipefail
# ────────────────────────────────────────────────────────────────
#  LockSure – end-to-end smoke test (alexaAuth → alexaToken → smart-home)
#  ❶ Adjust ONLY these 3 lines ↓
FB_UID="6ue1XtW8cndXJQyHydNo86PW1p43"                        # ← your Firebase UID
REST_API_ID="ayb2a2m447"                                     # ← your API-GW id
REGION="eu-west-1"                                           # ← your region
# ────────────────────────────────────────────────────────────────
API="https://${REST_API_ID}.execute-api.${REGION}.amazonaws.com/prod"
REDIRECT="https://layla.amazon.com/api/skill/link/amzn1.ask.skill.89751fb9-1b7f-4c40-8c9f-a5231bdb3998"

echo "🔗 1) /alexaAuth redirect (expect 302 + state)"
STATE=$(
  curl -sD - -o /dev/null -G \
    --data-urlencode uid="$FB_UID" \
    --data-urlencode redirect_uri="$REDIRECT" \
    "$API/alexaAuth" | tr -d '\r' | awk -F'state=' '/^location:/ {print $2}'
)
if [[ -z "$STATE" ]]; then echo "❌  state NOT returned – abort"; exit 1; fi
echo "   STATE=$STATE"

echo
echo "🎫 2) /alexaCallback → auth-code (fake ?code=poke)"
AUTH_CODE=$(
  curl -sD - -o /dev/null -G \
    --data-urlencode code=poke \
    --data-urlencode state="$STATE" \
    "$API/alexaCallback" | tr -d '\r' | awk -F'code=' '/^location:/ {print $2}'
)
if [[ -z "$AUTH_CODE" ]]; then echo "❌  auth-code NOT returned – abort"; exit 1; fi
echo "   AUTH_CODE=$AUTH_CODE"

echo
echo "🔑 3) /alexaToken exchange → access_token"
TOKEN_JSON=$(curl -s -X POST "$API/alexaToken" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode grant_type=authorization_code \
  --data-urlencode code="$AUTH_CODE" \
  --data-urlencode state="$STATE")
ACCESS_TOKEN=$(echo "$TOKEN_JSON" | jq -r .access_token 2>/dev/null || echo "")
if [[ "$ACCESS_TOKEN" != "$FB_UID" ]]; then
  echo "❌  token exchange failed: $TOKEN_JSON"; exit 1;
fi
echo "   access_token=$ACCESS_TOKEN ✔︎"

echo
echo "🏠 4) /smart-home Discovery (BearerToken = access_token)"
DISCOVERY=$(curl -s -X POST "$API/smart-home" \
  -H "Content-Type: application/json" \
  -d '{
        "directive":{
          "header":{"namespace":"Alexa.Discovery","name":"Discover","payloadVersion":"3","messageId":"smoke-001"},
          "payload":{"scope":{"type":"BearerToken","token":"'"$ACCESS_TOKEN"'" }}
        }
      }')
echo "$DISCOVERY" | jq '.' 2>/dev/null || echo "$DISCOVERY"

echo
echo "✅  Smoke test finished"
