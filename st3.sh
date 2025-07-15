#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────
# 🔧 CONFIG – change only these two lines
API_BASE="https://ayb2a2m447.execute-api.eu-west-1.amazonaws.com/prod"
FB_UID="6ue1XtW8cndXJQyHydNo86PW1p43"                 # ← your Firebase UID
# ─────────────────────────────────────────

SKILL_ID="89751fb9-1b7f-4c40-8c9f-a5231bdb3998"
REDIRECT_URI="https://layla.amazon.com/api/skill/link/${SKILL_ID}"

echo "🔗 1) /alexaAuth (expect 302)…"
STATE=$(curl -siG \
          --data-urlencode uid="$FB_UID" \
          --data-urlencode redirect_uri="$REDIRECT_URI" \
          "${API_BASE}/alexaAuth" |
        tr -d '\r' |
        awk -F'state=' '/^location:/ {print $2}')
echo "   STATE = $STATE"

echo -e "\n🎫 2) /alexaCallback (fake ?code=poke)…"
AUTH_CODE=$(curl -siG \
             --data-urlencode code=poke \
             --data-urlencode state="$STATE" \
             "${API_BASE}/alexaCallback" |
           tr -d '\r' |
           awk -F'code=' '/^location:/ {print $2}' | cut -d'&' -f1)
echo "   AUTH_CODE = $AUTH_CODE"

echo -e "\n🔑 3) /alexaToken exchange…"
TOKEN_JSON=$(curl -s -X POST "${API_BASE}/alexaToken" \
                -H 'Content-Type: application/x-www-form-urlencoded' \
                --data-urlencode grant_type=authorization_code \
                --data-urlencode code="$AUTH_CODE" \
                --data-urlencode state="$STATE")
echo "   $TOKEN_JSON"

ACCESS_TOKEN=$(echo "$TOKEN_JSON" | jq -r '.access_token')

echo -e "\n🏠 4) /smart-home Discovery…"
curl -s -X POST "${API_BASE}/smart-home" \
     -H 'Content-Type: application/json' \
     -d "{
           \"directive\": {
             \"header\": {
               \"namespace\": \"Alexa.Discovery\",
               \"name\": \"Discover\",
               \"payloadVersion\": \"3\",
               \"messageId\": \"smoke-test\"
             },
             \"payload\": {
               \"scope\": {
                 \"type\": \"BearerToken\",
                 \"token\": \"$ACCESS_TOKEN\"
               }
             }
           }
         }" | jq .

echo -e "\n✅ Smoke-test finished"
