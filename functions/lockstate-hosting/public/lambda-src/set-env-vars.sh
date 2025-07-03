#!/bin/bash

# Set environment variables for the Lambda function
FUNCTION_NAME="locksureSmartHomeProxy"
REGION="eu-west-1"

echo "Setting environment variables for $FUNCTION_NAME..."

aws lambda update-function-configuration \
  --function-name "$FUNCTION_NAME" \
  --region "$REGION" \
  --environment 'Variables={
    ALEXA_CLIENT_ID=amzn1.application-oa2-client.ddbcc3bfaf604d1980b699300a623698,
    ALEXA_CLIENT_SECRET=amzn1.oa2-cs.v1.6b02e945a9e3e041a43abdb405a1e76f80081db17080e5cca01962b90e21f815,
    LWA_AUTH_URL=https://www.amazon.com/ap/oa,
    LWA_TOKEN_URL=https://api.amazon.com/auth/o2/token
  }'

echo "Environment variables set successfully!"
echo ""
echo "Verifying configuration..."

aws lambda get-function-configuration \
  --function-name "$FUNCTION_NAME" \
  --region "$REGION" \
  --query 'Environment.Variables' \
  --output table 