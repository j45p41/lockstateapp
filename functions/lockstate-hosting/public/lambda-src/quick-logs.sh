#!/bin/bash

# Quick CloudWatch Logs Checker
# Simple script to quickly check Lambda logs

FUNCTION_NAME="locksureSmartHomeProxy"
LOG_GROUP_NAME="/aws/lambda/$FUNCTION_NAME"
REGION="eu-west-1"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🔍 Quick Log Check for $FUNCTION_NAME${NC}"
echo ""

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install it first."
    exit 1
fi

# Check credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured. Run 'aws configure' first."
    exit 1
fi

# Get the latest log stream
LATEST_STREAM=$(aws logs describe-log-streams \
    --log-group-name "$LOG_GROUP_NAME" \
    --region "$REGION" \
    --order-by LastEventTime \
    --descending \
    --max-items 1 \
    --query 'logStreams[0].logStreamName' \
    --output text 2>/dev/null)

if [ "$LATEST_STREAM" = "None" ] || [ -z "$LATEST_STREAM" ]; then
    echo "⚠️  No log streams found."
    exit 0
fi

echo -e "${YELLOW}📄 Latest Stream: $LATEST_STREAM${NC}"
echo "----------------------------------------"

# Get the last 20 events
aws logs get-log-events \
    --log-group-name "$LOG_GROUP_NAME" \
    --log-stream-name "$LATEST_STREAM" \
    --region "$REGION" \
    --start-from-head false \
    --limit 20 \
    --query 'events[*].[timestamp,message]' \
    --output table 2>/dev/null

echo ""
echo -e "${GREEN}✅ Log check complete${NC}" 