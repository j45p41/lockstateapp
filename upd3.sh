#!/usr/bin/env bash
set -euo pipefail
BASE='https://ayb2a2m447.execute-api.eu-west-1.amazonaws.com/prod'
UID='6ue1XtW8cndXJQyHydNo86PW1p43'

echo -e "\n🔗 1) /alexaAuth ..."
curl -siG "$BASE/alexaAuth" \
  --data-urlencode uid="$UID" \
  --data-urlencode redirect_uri='https://layla.amazon.com/api/skill/link/amzn1.ask.skill.89751fb9-1b7f-4c40-8c9f-a5231bdb3998' \
  | grep -i location

echo -e "\n🔑 2) /alexaToken quick round-trip ..."
STATE='dummy'
CODE='dummy'
curl -s -X POST "$BASE/alexaToken" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "grant_type=authorization_code&code=$CODE&state=$STATE" | jq .

echo -e "\n🔎 3) /smart-home Discover ..."
curl -s -X POST "$BASE/smart-home" -H 'Content-Type: application/json' -d "{
  \"directive\":{
    \"header\":{\"namespace\":\"Alexa.Discovery\",\"name\":\"Discover\",\"payloadVersion\":\"3\",\"messageId\":\"cli-test\"},
    \"payload\":{\"scope\":{\"type\":\"BearerToken\",\"token\":\"$UID\"}}
  }}" | jq .
