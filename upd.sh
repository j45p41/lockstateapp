#!/usr/bin/env bash
set -euo pipefail
export AWS_PAGER=""

############ 1) CONFIG  #######################################################
REGION="eu-west-1"
REST_API_ID="ayb2a2m447"                 #  ← your API-Gateway REST API id
STAGE="prod"                             #  ← stage name
LAMBDA_FN="locksureSmartHomeProxyV2"     #  new function name
LAMBDA_ARN="arn:aws:lambda:${REGION}:487228065075:function:${LAMBDA_FN}"
FB_UID="6ue1XtW8cndXJQyHydNo86PW1p43"    #  ← real Firebase UID for quick test

###############################################################################
echo "➜  Locating resource-ids …"
read -r AUTH_ID CALLBACK_ID TOKEN_ID SH_ID PROXY_ID <<<"$(
  aws apigateway get-resources --rest-api-id "$REST_API_ID" --region "$REGION" \
    --query 'items[?path==`/alexaAuth`].id \
                    || items[?path==`/alexaCallback`].id \
                    || items[?path==`/alexaToken`].id \
                    || items[?path==`/smart-home`].id \
                    || items[?path==`/{proxy+}`].id' --output text
)"
echo "   /alexaAuth      = $AUTH_ID"
echo "   /alexaCallback  = $CALLBACK_ID"
echo "   /alexaToken     = $TOKEN_ID"
echo "   /smart-home     = $SH_ID"
echo "   /{proxy+}       = $PROXY_ID"

###############################################################################
echo -e "\n➜  Updating integrations to ${LAMBDA_FN} …"
for RID in $AUTH_ID $CALLBACK_ID $TOKEN_ID $SH_ID $PROXY_ID; do
  [[ -z "$RID" ]] && continue
  aws apigateway put-integration \
    --rest-api-id "$REST_API_ID" \
    --resource-id "$RID" \
    --http-method ANY \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations" \
    --region "$REGION" >/dev/null
done
echo "   ✔ integrations now point at ${LAMBDA_FN}"

###############################################################################
echo -e "\n➜  Adding lambda:InvokeFunction permission (id=allowApiInvokeV2) …"
aws lambda add-permission \
  --function-name "$LAMBDA_FN" \
  --statement-id  allowApiInvokeV2 \
  --action        lambda:InvokeFunction \
  --principal     apigateway.amazonaws.com \
  --source-arn    "arn:aws:execute-api:${REGION}:487228065075:${REST_API_ID}/${STAGE}/ANY/*" \
  --region        "$REGION" 2>/dev/null || echo "   (permission already present)"

###############################################################################
echo -e "\n➜  Deploying new stage snapshot …"
aws apigateway create-deployment \
  --rest-api-id "$REST_API_ID" \
  --stage-name  "$STAGE" \
  --region      "$REGION" \
  --description "Point ${STAGE} at ${LAMBDA_FN}" >/dev/null
echo "   ✔ deployment created – allow ~30 s for cache to clear"

###############################################################################
echo -e "\n================  QUICK SMOKE TESTS  ================\n"
BASE="https://${REST_API_ID}.execute-api.${REGION}.amazonaws.com/${STAGE}"

### 1) /alexaAuth redirect (state param present?)
echo "1️⃣  /alexaAuth redirect:"
curl -siG --data-urlencode uid="${FB_UID}" --data-urlencode redirect_uri="https://layla.amazon.com" \
     "${BASE}/alexaAuth" | grep -iE "HTTP/|location:"
echo; echo

### 2) /alexaToken happy-path (fake auth-code)
TEST_STATE="dummy"
TEST_CODE="dummycode"
aws dynamodb put-item --table-name alexaCodes --item \
  "{\"id\":{\"S\":\"${TEST_CODE}\"},\"uid\":{\"S\":\"${FB_UID}\"},\"state\":{\"S\":\"${TEST_STATE}\"},\"used\":{\"BOOL\":false}}" >/dev/null || true

echo "2️⃣  /alexaToken exchange:"
curl -s -X POST "${BASE}/alexaToken" \
     -H "Content-Type: application/x-www-form-urlencoded" \
     --data-urlencode grant_type=authorization_code \
     --data-urlencode code="${TEST_CODE}" \
     --data-urlencode state="${TEST_STATE}" | jq .
echo

### 3) /smart-home discovery (rooms should be returned if any)
echo "3️⃣  /smart-home Discovery directive:"
curl -s -X POST "${BASE}/smart-home" \
     -H "Content-Type: application/json" \
     -d "{
            \"directive\":{\"header\":{\"namespace\":\"Alexa.Discovery\",\"name\":\"Discover\",\"payloadVersion\":\"3\",\"messageId\":\"test\"},
            \"payload\":{\"scope\":{\"type\":\"BearerToken\",\"token\":\"${FB_UID}\"}}}
         }" | jq .
echo
echo "====================================================="
