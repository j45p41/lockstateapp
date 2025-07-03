#!/bin/bash

# LockState Lambda - Deploy and Monitor Script
# This script deploys the Lambda function and then monitors logs

# Configuration
FUNCTION_NAME="locksureSmartHomeProxy"
REGION="eu-west-1"
LOG_GROUP_NAME="/aws/lambda/$FUNCTION_NAME"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== LockState Lambda Deploy & Monitor ===${NC}"
echo -e "${BLUE}Function:${NC} $FUNCTION_NAME"
echo -e "${BLUE}Region:${NC} $REGION"
echo ""

# Function to check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}🔍 Checking prerequisites...${NC}"
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}❌ AWS CLI not found. Please install it first.${NC}"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        echo -e "${RED}❌ AWS credentials not configured. Run 'aws configure' first.${NC}"
        exit 1
    fi
    
    # Check if zip is available
    if ! command -v zip &> /dev/null; then
        echo -e "${RED}❌ zip command not found. Please install it.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Prerequisites check passed${NC}"
    echo ""
}

# Function to deploy Lambda
deploy_lambda() {
    echo -e "${YELLOW}🚀 Deploying Lambda function...${NC}"
    
    # Create deployment package
    echo "📦 Creating deployment package..."
    rm -f function.zip
    zip -r function.zip . -x "*.git*" "node_modules/*" "*.DS_Store" "deploy-*.sh" "check-*.sh" "quick-*.sh"
    
    if [ ! -f function.zip ]; then
        echo -e "${RED}❌ Failed to create deployment package${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Deployment package created: $(ls -lh function.zip | awk '{print $5}')${NC}"
    
    # Update Lambda function
    echo "📤 Uploading to AWS Lambda..."
    aws lambda update-function-code \
        --function-name "$FUNCTION_NAME" \
        --zip-file fileb://function.zip \
        --region "$REGION" \
        --output table
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Lambda function updated successfully${NC}"
    else
        echo -e "${RED}❌ Failed to update Lambda function${NC}"
        exit 1
    fi
    
    # Clean up
    rm -f function.zip
    echo ""
}

# Function to wait for deployment
wait_for_deployment() {
    echo -e "${YELLOW}⏳ Waiting for deployment to complete...${NC}"
    
    # Wait for the function to be ready
    aws lambda wait function-updated \
        --function-name "$FUNCTION_NAME" \
        --region "$REGION"
    
    echo -e "${GREEN}✅ Deployment completed${NC}"
    echo ""
}

# Function to show function info
show_function_info() {
    echo -e "${YELLOW}📊 Function Information${NC}"
    echo "----------------------------------------"
    
    aws lambda get-function \
        --function-name "$FUNCTION_NAME" \
        --region "$REGION" \
        --query '{
            FunctionName: Configuration.FunctionName,
            Runtime: Configuration.Runtime,
            Handler: Configuration.Handler,
            CodeSize: Configuration.CodeSize,
            Description: Configuration.Description,
            Timeout: Configuration.Timeout,
            MemorySize: Configuration.MemorySize,
            LastModified: Configuration.LastModified
        }' \
        --output table
    
    echo ""
}

# Function to monitor logs
monitor_logs() {
    echo -e "${YELLOW}👀 Starting log monitoring...${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop monitoring${NC}"
    echo ""
    
    # Get the latest stream
    LATEST_STREAM=$(aws logs describe-log-streams \
        --log-group-name "$LOG_GROUP_NAME" \
        --region "$REGION" \
        --order-by LastEventTime \
        --descending \
        --max-items 1 \
        --query 'logStreams[0].logStreamName' \
        --output text 2>/dev/null)
    
    if [ "$LATEST_STREAM" = "None" ] || [ -z "$LATEST_STREAM" ]; then
        echo "⚠️  No log streams found. Waiting for new logs..."
    else
        echo -e "${GREEN}📄 Monitoring stream: $LATEST_STREAM${NC}"
    fi
    
    echo "----------------------------------------"
    
    # Follow logs in real-time
    aws logs tail "$LOG_GROUP_NAME" \
        --region "$REGION" \
        --since 1m \
        --follow 2>/dev/null
}

# Function to show recent logs
show_recent_logs() {
    echo -e "${YELLOW}📋 Recent Logs (last 10 minutes)${NC}"
    echo "----------------------------------------"
    
    # Calculate start time (10 minutes ago)
    START_TIME=$(($(date +%s) - 600))000
    
    # Get recent log streams
    STREAMS=$(aws logs describe-log-streams \
        --log-group-name "$LOG_GROUP_NAME" \
        --region "$REGION" \
        --order-by LastEventTime \
        --descending \
        --query 'logStreams[?lastEventTimestamp > `'$START_TIME'`].logStreamName' \
        --output text 2>/dev/null)
    
    if [ -z "$STREAMS" ]; then
        echo "⚠️  No recent logs found"
        return
    fi
    
    # Get logs from each stream
    for stream in $STREAMS; do
        echo -e "${GREEN}📄 Stream: $stream${NC}"
        aws logs get-log-events \
            --log-group-name "$LOG_GROUP_NAME" \
            --log-stream-name "$stream" \
            --region "$REGION" \
            --start-time "$START_TIME" \
            --query 'events[*].[timestamp,message]' \
            --output table 2>/dev/null
        echo ""
    done
}

# Function to search for errors
search_errors() {
    echo -e "${YELLOW}🔍 Searching for errors in recent logs...${NC}"
    echo "----------------------------------------"
    
    # Calculate start time (30 minutes ago)
    START_TIME=$(($(date +%s) - 1800))000
    
    # Get recent log streams
    STREAMS=$(aws logs describe-log-streams \
        --log-group-name "$LOG_GROUP_NAME" \
        --region "$REGION" \
        --order-by LastEventTime \
        --descending \
        --query 'logStreams[?lastEventTimestamp > `'$START_TIME'`].logStreamName' \
        --output text 2>/dev/null)
    
    if [ -z "$STREAMS" ]; then
        echo "⚠️  No recent logs found"
        return
    fi
    
    # Search for errors in each stream
    for stream in $STREAMS; do
        echo -e "${GREEN}📄 Searching in: $stream${NC}"
        aws logs get-log-events \
            --log-group-name "$LOG_GROUP_NAME" \
            --log-stream-name "$stream" \
            --region "$REGION" \
            --start-time "$START_TIME" \
            --query 'events[?contains(message, `ERROR`) || contains(message, `error`) || contains(message, `Error`)][timestamp,message]' \
            --output table 2>/dev/null
        echo ""
    done
}

# Main menu
show_menu() {
    echo -e "${BLUE}Choose an option:${NC}"
    echo "1) Deploy and monitor logs"
    echo "2) Deploy only"
    echo "3) Monitor logs only"
    echo "4) Show recent logs"
    echo "5) Search for errors"
    echo "6) Show function info"
    echo "7) Exit"
    echo ""
}

# Main script logic
main() {
    case "${1:-}" in
        "deploy-monitor"|"1")
            check_prerequisites
            deploy_lambda
            wait_for_deployment
            show_function_info
            monitor_logs
            ;;
        "deploy"|"2")
            check_prerequisites
            deploy_lambda
            wait_for_deployment
            show_function_info
            ;;
        "monitor"|"3")
            monitor_logs
            ;;
        "logs"|"4")
            show_recent_logs
            ;;
        "errors"|"5")
            search_errors
            ;;
        "info"|"6")
            show_function_info
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [option]"
            echo ""
            echo "Options:"
            echo "  deploy-monitor, 1    Deploy and monitor logs"
            echo "  deploy, 2           Deploy only"
            echo "  monitor, 3          Monitor logs only"
            echo "  logs, 4             Show recent logs"
            echo "  errors, 5           Search for errors"
            echo "  info, 6             Show function info"
            echo "  help                Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 deploy-monitor"
            echo "  $0 deploy"
            echo "  $0 monitor"
            echo "  $0 logs"
            ;;
        "")
            show_menu
            read -p "Enter your choice (1-7): " choice
            case "$choice" in
                1) 
                    check_prerequisites
                    deploy_lambda
                    wait_for_deployment
                    show_function_info
                    monitor_logs
                    ;;
                2) 
                    check_prerequisites
                    deploy_lambda
                    wait_for_deployment
                    show_function_info
                    ;;
                3) monitor_logs ;;
                4) show_recent_logs ;;
                5) search_errors ;;
                6) show_function_info ;;
                7) echo "Goodbye!"; exit 0 ;;
                *) echo "Invalid choice. Exiting."; exit 1 ;;
            esac
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use '$0 help' for usage information."
            exit 1
            ;;
    esac
}

# Run the main function
main "$@" 