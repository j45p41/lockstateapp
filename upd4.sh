#!/usr/bin/env bash
set -euo pipefail

############################################################
#  Change *just these two* lines when you test in the future
############################################################
FB_UID='6ue1XtW8cndXJQyHydNo86PW1p43'        # ← your Firebase UID
BASE='https://ayb2a2m447.execute-api.eu-west-1.amazonaws.com/prod'

AWS_REGION='eu-west-1'
LAMBDA_FN='locksureSmartHomeProxyV2'          # target Lambda
REST_API_ID='ayb2a2m447'                     # API-GW ID
############################################################

echo -e "\n🔗 1) /alexaAuth redirect test"
curl -siG "$BASE/alexaAuth" \
  --data-urlencode uid="$FB_UID" \
  --data-urlencode redirect_uri='https://layla.amazon.com/api/skill/link/amzn1.ask.skill.89751fb9-1b7f-4c40-8c9f-a5231bdb3998' \
  | grep -i '^location'

echo -e "\n🔧 2) Sanity-check proxy → $LAMBDA_FN"
aws apigateway get-integration \
  --rest-api-id "$REST_API_ID" \
  --resource-id  "$(aws apigateway get-resources --rest-api-id "$REST_API_ID" --query "items[?path=='/{proxy+}'].id" --output text)" \
  --http-method  ANY \
  --region "$AWS_REGION" \
  --query '{type:type,lambda:uri}' --output table

echo -e "\n🔎 3) /smart-home Discovery with BearerToken = Firebase UID"
curl -s -X POST "$BASE/smart-home" -H 'Content-Type: application/json' -d "{
  \"directive\":{
    \"header\":{\"namespace\":\"Alexa.Discovery\",\"name\":\"Discover\",\"payloadVersion\":\"3\",\"messageId\":\"cli-test\"},
    \"payload\":{\"scope\":{\"type\":\"BearerToken\",\"token\":\"$FB_UID\"}}
  }}" | jq .

echo -e "\n✅  Script finished"
