#!/bin/bash

# Create API Gateway for Alexa account linking
API_NAME="locksure-alexa-api"
REGION="eu-west-1"
FUNCTION_NAME="locksureSmartHomeProxy"
FUNCTION_ARN="arn:aws:lambda:eu-west-1:$(aws sts get-caller-identity --query Account --output text):function:$FUNCTION_NAME"

echo "Creating API Gateway: $API_NAME..."

# Create REST API
API_ID=$(aws apigateway create-rest-api \
  --name "$API_NAME" \
  --description "API Gateway for Alexa account linking" \
  --region "$REGION" \
  --query 'id' \
  --output text)

echo "API Gateway created with ID: $API_ID"

# Get root resource ID
ROOT_ID=$(aws apigateway get-resources \
  --rest-api-id "$API_ID" \
  --region "$REGION" \
  --query 'items[?path==`/`].id' \
  --output text)

echo "Root resource ID: $ROOT_ID"

# Create /alexaAuth resource
AUTHAUTH_ID=$(aws apigateway create-resource \
  --rest-api-id "$API_ID" \
  --parent-id "$ROOT_ID" \
  --path-part "alexaAuth" \
  --region "$REGION" \
  --query 'id' \
  --output text)

echo "Created /alexaAuth resource: $AUTHAUTH_ID"

# Create /alexaToken resource
AUTHTOKEN_ID=$(aws apigateway create-resource \
  --rest-api-id "$API_ID" \
  --parent-id "$ROOT_ID" \
  --path-part "alexaToken" \
  --region "$REGION" \
  --query 'id' \
  --output text)

echo "Created /alexaToken resource: $AUTHTOKEN_ID"

# Add GET method to /alexaAuth
aws apigateway put-method \
  --rest-api-id "$API_ID" \
  --resource-id "$AUTHAUTH_ID" \
  --http-method GET \
  --authorization-type NONE \
  --region "$REGION"

echo "Added GET method to /alexaAuth"

# Add POST method to /alexaToken
aws apigateway put-method \
  --rest-api-id "$API_ID" \
  --resource-id "$AUTHTOKEN_ID" \
  --http-method POST \
  --authorization-type NONE \
  --region "$REGION"

echo "Added POST method to /alexaToken"

# Add Lambda integration to /alexaAuth
aws apigateway put-integration \
  --rest-api-id "$API_ID" \
  --resource-id "$AUTHAUTH_ID" \
  --http-method GET \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/$FUNCTION_ARN/invocations" \
  --region "$REGION"

echo "Added Lambda integration to /alexaAuth"

# Add Lambda integration to /alexaToken
aws apigateway put-integration \
  --rest-api-id "$API_ID" \
  --resource-id "$AUTHTOKEN_ID" \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/$FUNCTION_ARN/invocations" \
  --region "$REGION"

echo "Added Lambda integration to /alexaToken"

# Add Lambda permission for API Gateway
aws lambda add-permission \
  --function-name "$FUNCTION_NAME" \
  --statement-id apigateway-access \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:$REGION:$(aws sts get-caller-identity --query Account --output text):$API_ID/*/*" \
  --region "$REGION"

echo "Added Lambda permission for API Gateway"

# Deploy the API
DEPLOYMENT_ID=$(aws apigateway create-deployment \
  --rest-api-id "$API_ID" \
  --stage-name prod \
  --region "$REGION" \
  --query 'id' \
  --output text)

echo "Deployed API with deployment ID: $DEPLOYMENT_ID"

# Get the API URL
API_URL="https://$API_ID.execute-api.$REGION.amazonaws.com/prod"
echo ""
echo "✅ API Gateway created successfully!"
echo "API URL: $API_URL"
echo ""
echo "Alexa Account Linking URLs:"
echo "Web Authorization URI: $API_URL/alexaAuth"
echo "Access Token URI: $API_URL/alexaToken"
echo ""
echo "Update these URLs in your Alexa Developer Console!" 