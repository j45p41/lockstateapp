#!/usr/bin/env bash
set -euo pipefail
REGION=eu-west-1
ACCOUNT=487228065075
REST_API=18glpgnilb
LAMBDA_FN=locksureSmartHomeProxy

echo "▶ Fetching resource-IDs …"
mapfile -t IDS < <(
  aws apigateway get-resources \
    --region "$REGION" \
    --rest-api-id "$REST_API" \
    --query 'items[?path==`/alexaAuth` || path==`/alexaCallback` || path==`/alexaToken`].[path,id]' \
    --output text
)
declare -A RID
for ((i=0;i<${#IDS[@]};i+=2)); do
  RID[${IDS[i]}]=${IDS[i+1]}
done

AUTH_ID=${RID[/alexaAuth]}
CALL_ID=${RID[/alexaCallback]}
TOK_ID=${RID[/alexaToken]}

LAMBDA_URI="arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/arn:aws:lambda:$REGION:$ACCOUNT:function:$LAMBDA_FN/invocations"

echo "▶ 1/4  clean out extra methods under /alexaAuth …"
for verb in GET POST; do
  aws apigateway delete-method --rest-api-id "$REST_API" \
    --region "$REGION" --resource-id "$AUTH_ID" \
    --http-method "$verb" 2>/dev/null || true
done

echo "▶ 2/4  ensure POST (+ keep ANY) on /alexaAuth …"
aws apigateway put-method            \
  --rest-api-id "$REST_API"          \
  --region     "$REGION"             \
  --resource-id "$AUTH_ID"           \
  --http-method POST                 \
  --authorization-type NONE          >/dev/null

aws apigateway put-integration                \
  --rest-api-id "$REST_API"                   \
  --region     "$REGION"                      \
  --resource-id "$AUTH_ID"                    \
  --http-method POST                          \
  --type AWS_PROXY                            \
  --integration-http-method POST              \
  --uri "$LAMBDA_URI"                         >/dev/null

echo "▶ 3/4  Lambda-side permission for POST …"
aws lambda add-permission  --region "$REGION" \
  --function-name  "$LAMBDA_FN"               \
  --statement-id   allowGatewayProdAuthPOST   \
  --action         lambda:InvokeFunction      \
  --principal      apigateway.amazonaws.com   \
  --source-arn     "arn:aws:execute-api:$REGION:$ACCOUNT:$REST_API/*/POST/alexaAuth" \
  >/dev/null || true   # idempotent – ignore “Sid exists” errors

echo "▶ 4/4  deploy to prod …"
aws apigateway create-deployment          \
     --rest-api-id "$REST_API"            \
     --region "$REGION"                   \
     --stage-name prod                    \
     --description "fix POST & permissions" >/dev/null

echo "✅   API redeployed.  CloudFront needs ~30 s to flush."
