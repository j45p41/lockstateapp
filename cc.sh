#!/usr/bin/env bash
set -e

# 1) point at your API
export AWS_PAGER=""  
export REST_API_ID=ayb2a2m447  
export REGION=eu-west-1

echo
echo "➜ 1) Find the proxy resource (“/{proxy+}”)"
PROXY_ID=$(aws apigateway get-resources \
    --rest-api-id $REST_API_ID \
    --region      $REGION \
    --query       "items[?path=='/{proxy+}'].id" \
    --output      text)
echo "    /{proxy+} resource-id = $PROXY_ID"

echo
echo "➜ 2) Show the ANY method configuration on /{proxy+}:"
aws apigateway get-method \
    --rest-api-id $REST_API_ID \
    --resource-id $PROXY_ID \
    --http-method ANY \
    --region      $REGION

echo
echo "➜ 3) Show the integration on ANY /{proxy+}:"
aws apigateway get-integration \
    --rest-api-id $REST_API_ID \
    --resource-id $PROXY_ID \
    --http-method ANY \
    --region      $REGION
