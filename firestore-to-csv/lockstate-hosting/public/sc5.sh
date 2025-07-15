#!/usr/bin/env bash
set -euo pipefail

# ─── CONFIG ────────────────────────────────────────────────────────────────
REST_API_ID="ayb2a2m447"
REGION="eu-west-1"

# the Lambda you use for /alexaAuth, /alexaCallback & /alexaToken:
LINK_LAMBDA_ARN="arn:aws:lambda:${REGION}:487228065075:function:locksureSmartHomeProxy"

# ─── 1) grab the root resource ID ───────────────────────────────────────────
ROOT_ID=$(
  aws apigateway get-resources \
    --rest-api-id $REST_API_ID \
    --region $REGION \
    --query "items[?path=='/'].id" \
    --output text
)
echo "root resource-id = $ROOT_ID"

# ─── helper to create & wire up one path ────────────────────────────────────
create_route() {
  local PATH_PART=$1
  local RESOURCE_NAME=$2

  echo
  echo "▶ creating /${PATH_PART}"
  NEW_ID=$(
    aws apigateway create-resource \
      --rest-api-id $REST_API_ID \
      --region $REGION \
      --parent-id $ROOT_ID \
      --path-part $PATH_PART \
    | jq -r .id
  )
  echo "  → resource-id = $NEW_ID"

  echo "  • PUT_METHOD ANY"
  aws apigateway put-method \
    --rest-api-id $REST_API_ID \
    --region $REGION \
    --resource-id $NEW_ID \
    --http-method ANY \
    --authorization-type NONE

  echo "  • PUT_INTEGRATION AWS_PROXY → $LINK_LAMBDA_ARN"
  aws apigateway put-integration \
    --rest-api-id $REST_API_ID \
    --region $REGION \
    --resource-id $NEW_ID \
    --http-method ANY \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${LINK_LAMBDA_ARN}/invocations"
}

# ─── 2) create the three account-linking routes ─────────────────────────────
create_route alexaAuth    alexaAuth
create_route alexaCallback alexaCallback
create_route alexaToken   alexaToken

# ─── 3) add invoke-permission for each to your Lambda ───────────────────────
echo
for PATH in alexaAuth alexaCallback alexaToken; do
  echo "▶ lambda:add-permission for /${PATH}"
  aws lambda add-permission \
    --function-name locksureSmartHomeProxy \
    --statement-id allowApiInvoke_${PATH} \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${REGION}:487228065075:${REST_API_ID}/prod/ANY/${PATH}" \
    --region $REGION \
    || echo "   (warning: permission may already exist)"
done

# ─── 4) redeploy stage ──────────────────────────────────────────────────────
echo
echo "▶ creating new deployment"
aws apigateway create-deployment \
  --rest-api-id $REST_API_ID \
  --stage-name prod \
  --region $REGION

echo
echo "✅ Done! Wait ~30s, then re-run your smoke tests:"
echo "   STATE=\$(curl -s -D- - -G \\"
echo "     --data-urlencode uid=6ue1XtW8cndXJQyHydNo86PW1p43 \\"
echo "     --data-urlencode redirect_uri=https://layla.amazon.com/api/skill/link/amzn1.ask.skill.89751fb9-1b7f-4c40-8c9f-a5231bdb3998 \\"
echo "     https://${REST_API_ID}.execute-api.${REGION}.amazonaws.com/prod/alexaAuth \\"
echo "     | awk -F'state=' '/^location:/ {print \$2}')"
echo
echo "   curl -s -D- - -G \\"
echo "     --data-urlencode code=poke \\"
echo "     --data-urlencode state=\$STATE \\"
echo "     https://${REST_API_ID}.execute-api.${REGION}.amazonaws.com/prod/alexaCallback"
