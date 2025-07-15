#!/usr/bin/env bash
API="https://ayb2a2m447.execute-api.eu-west-1.amazonaws.com/prod"
UID="6ue1XtW8cndXJQyHydNo86PW1p43"         # <-- your Firebase UID
REDIRECT="https://layla.amazon.com/api/skill/link/$SKILL_ID"

echo "🔗 1) /alexaAuth ..."
STATE=$(curl -siG --data-urlencode uid=$UID --data-urlencode redirect_uri=$REDIRECT \
        $API/alexaAuth | awk -F'state=' '/^location:/ {print $2}')
echo "   STATE=$STATE"

echo -e "\n🎫 2) /alexaCallback ..."
AUTH_CODE=$(curl -siG --data-urlencode code=poke --data-urlencode state="$STATE" \
            $API/alexaCallback | awk -F'code=' '/^location:/ {print $2}' | cut -d'&' -f1)
echo "   AUTH_CODE=$AUTH_CODE"

echo -e "\n🔑 3) /alexaToken ..."
ACCESS=$(curl -s -X POST $API/alexaToken -H 'Content-Type: application/x-www-form-urlencoded' \
         --data-urlencode grant_type=authorization_code \
         --data-urlencode code=$AUTH_CODE \
         --data-urlencode state=$STATE)
echo "   $ACCESS"

echo -e "\n🏠 4) /smart-home Discover ..."
curl -s -X POST $API/smart-home -H 'Content-Type: application/json' -d "{
  \"directive\":{
    \"header\":{\"namespace\":\"Alexa.Discovery\",\"name\":\"Discover\",\"payloadVersion\":\"3\",\"messageId\":\"smoke-test\"},
    \"payload\":{\"scope\":{\"type\":\"BearerToken\",\"token\":\"$UID\"}}
  }
}" | jq .
