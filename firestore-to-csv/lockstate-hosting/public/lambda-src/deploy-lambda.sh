#!/bin/bash
set -e

ZIP_NAME="lambda-deploy.zip"
LAMBDA_FUNCTION_NAME="locksureSmartHomeProxy"
REGION="eu-west-1"

# Zip only the correct Lambda source
zip -r $ZIP_NAME index.cjs package.json node_modules lockstate-e72fc-66f29588f54f.json

echo "Deploying $ZIP_NAME to AWS Lambda function: $LAMBDA_FUNCTION_NAME in region $REGION..."
aws lambda update-function-code \
  --function-name $LAMBDA_FUNCTION_NAME \
  --zip-file fileb://$ZIP_NAME \
  --region $REGION

# Ensure the handler is set correctly
aws lambda update-function-configuration \
  --function-name $LAMBDA_FUNCTION_NAME \
  --handler index.handler \
  --region $REGION

echo "Deployment complete!" 