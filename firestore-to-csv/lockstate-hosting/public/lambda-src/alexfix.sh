#!/usr/bin/env bash
set -euo pipefail

REGION=eu-west-1
ACCOUNT=487228065075
REST_API=18glpgnilb
LAMBDA_FN=locksureSmartHomeProxy

echo "▶ locating resource-IDs …"
AUTH_ID=$(aws apigateway get-resources \
           --region "$REGION" --rest-api-id "$REST_API" \
           --query "items[?path=='/alexaAuth'].id | [0]" \
           --output text)
CALL_ID=$(aws apigateway get-resources \
           --region "$REGION" --rest-api-id "$REST_API" \
           --query "items[?path=='/alexaCallback'].id | [0]" \
           --output text)
TOK_ID=$(aws apigateway get-resources \
           --region "$REGION" --rest-api-id "$REST_API" \
           --query "items[?path=='/alexaToken'].id | [0]" \
           --output text)

[[ $AUTH_ID == "None" || -z $AUTH_ID ]] && { echo "❌ /alexaAuth not found"; exit 1; }

LAMBDA_URI="arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/arn:aws:lambda:$REGION:$ACCOUNT:function:$LAMBDA_FN/invocations"

echo "▶ 1/4  delete stray GET/POST under /alexaAuth"
for verb in GET POST; do
  aws apigateway delete-method        \
       --rest-api-id "$REST_API"      \
       --region "$REGION"             \
       --resource-id "$AUTH_ID"       \
       --http-method "$verb" >/dev/null 2>&1 || true
done

echo "▶ 2/4  create POST + integration"
aws apigateway put-method            \
     --rest-api-id "$REST_API"       \
     --region     "$REGION"          \
     --resource-id "$AUTH_ID"        \
     --http-method POST              \
     --authorization-type NONE       >/dev/null

aws apigateway put-integration                \
     --rest-api-id "$REST_API"                \
     --region     "$REGION"                   \
     --resource-id "$AUTH_ID"                 \
     --http-method POST                       \
     --type AWS_PROXY                         \
     --integration-http-method POST           \
     --uri "$LAMBDA_URI"                      >/dev/null

echo "▶ 3/4  lambda permission for POST"
aws lambda add-permission          --region "$REGION" \
     --function-name  "$LAMBDA_FN"                    \
     --statement-id   allowGatewayProdAuthPOST        \
     --action         lambda:InvokeFunction           \
     --principal      apigateway.amazonaws.com        \
     --source-arn     "arn:aws:execute-api:$REGION:$ACCOUNT:$REST_API/*/POST/alexaAuth" \
     >/dev/null 2>&1 || true

echo "▶ 4/4  deploy → prod"
aws apigateway create-deployment   \
     --rest-api-id "$REST_API"     \
     --region "$REGION"            \
     --stage-name prod             \
     --description "fix POST & permissions" >/dev/null

echo "✅  Done.  Wait ~30 s for CloudFront cache to flush."
