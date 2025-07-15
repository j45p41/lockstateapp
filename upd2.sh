#!/usr/bin/env bash
set -euo pipefail
REST_API_ID=ayb2a2m447
REGION=eu-west-1
LAMBDA_FN=locksureSmartHomeProxyV2            # <- the only Lambda we touch
STAGE=prod

echo "➜  Fetching resource-ids …"
read AUTH_ID CALLBACK_ID TOKEN_ID SH_ID PROXY_ID < <(
  aws apigateway get-resources \
    --rest-api-id $REST_API_ID --region $REGION \
    --query '[].{p:path,i:id}[?p==`/alexaAuth` || p==`/alexaCallback` || p==`/alexaToken` || p==`/smart-home` || p==`/{proxy+}`].[i]' \
    --output text | xargs
)

printf "   /alexaAuth      = %s\n"  "$AUTH_ID"
printf "   /alexaCallback  = %s\n"  "$CALLBACK_ID"
printf "   /alexaToken     = %s\n"  "$TOKEN_ID"
printf "   /smart-home     = %s\n"  "$SH_ID"
printf "   /{proxy+}       = %s\n"  "$PROXY_ID"

echo -e "\n➜  Pointing ALL paths at λ $LAMBDA_FN …"
for ID in $AUTH_ID $CALLBACK_ID $TOKEN_ID $SH_ID $PROXY_ID; do
  aws apigateway put-integration \
      --rest-api-id $REST_API_ID --region $REGION \
      --resource-id $ID          --http-method ANY \
      --type AWS_PROXY           \
      --integration-http-method POST \
      --uri arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/arn:aws:lambda:$REGION:487228065075:function:$LAMBDA_FN/invocations >/dev/null
done
echo "   ✔ integrations updated"

echo -e "\n➜  Ensuring λ permission exists …"
aws lambda add-permission --function-name $LAMBDA_FN \
  --statement-id allowApiInvokeV2 --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:$REGION:487228065075:$REST_API_ID/$STAGE/ANY/*" \
  --region $REGION 2>/dev/null || echo "   (permission already present)"

echo -e "\n➜  Deploying stage …"
aws apigateway create-deployment --rest-api-id $REST_API_ID \
  --stage-name $STAGE --region $REGION >/dev/null
echo "   ✔ deployment kicked; give CloudFront ~30 s\n"

echo "================  QUICK SMOKE TESTS  ================"
BASE="https://${REST_API_ID}.execute-api.${REGION}.amazonaws.com/${STAGE}"
UID="6ue1XtW8cndXJQyHydNo86PW1p43"

echo -e "\n1️⃣  /smart-home Discovery:"
curl -s -X POST "$BASE/smart-home" -H "Content-Type: application/json" -d "{
  \"directive\":{
    \"header\":{\"namespace\":\"Alexa.Discovery\",\"name\":\"Discover\",\"payloadVersion\":\"3\",\"messageId\":\"cli-test\"},
    \"payload\":{\"scope\":{\"type\":\"BearerToken\",\"token\":\"$UID\"}}
  }}" | jq .

echo -e "\n2️⃣  Tail Lambda logs (Ctrl-C to quit)…"
aws logs tail /aws/lambda/$LAMBDA_FN --since 2m --follow
