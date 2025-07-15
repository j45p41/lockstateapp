#!/bin/bash

# CloudWatch Logs Checker for LockState Lambda
# This script fetches the latest logs from CloudWatch

# Configuration
FUNCTION_NAME="locksureSmartHomeProxy"
LOG_GROUP_NAME="/aws/lambda/$FUNCTION_NAME"
REGION="eu-west-1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== CloudWatch Logs Checker ===${NC}"
echo -e "${BLUE}Function:${NC} $FUNCTION_NAME"
echo -e "${BLUE}Region:${NC} $REGION"
echo -e "${BLUE}Log Group:${NC} $LOG_GROUP_NAME"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS credentials not configured. Please run 'aws configure' first.${NC}"
    exit 1
fi

# Function to get the latest log stream
get_latest_log_stream() {
    aws logs describe-log-streams \
        --log-group-name "$LOG_GROUP_NAME" \
        --region "$REGION" \
        --order-by LastEventTime \
        --descending \
        --max-items 1 \
        --query 'logStreams[0].logStreamName' \
        --output text 2>/dev/null
}

# Function to get logs from a specific stream
get_logs_from_stream() {
    local stream_name="$1"
    local start_time="$2"
    
    aws logs get-log-events \
        --log-group-name "$LOG_GROUP_NAME" \
        --log-stream-name "$stream_name" \
        --region "$REGION" \
        --start-time "$start_time" \
        --query 'events[*].[timestamp,message]' \
        --output table 2>/dev/null
}

# Function to get logs from the last N minutes
get_recent_logs() {
    local minutes="$1"
    local start_time=$(($(date +%s) - (minutes * 60)))000
    
    echo -e "${YELLOW}📋 Fetching logs from the last $minutes minutes...${NC}"
    echo ""
    
    # Get all log streams
    local streams=$(aws logs describe-log-streams \
        --log-group-name "$LOG_GROUP_NAME" \
        --region "$REGION" \
        --order-by LastEventTime \
        --descending \
        --query 'logStreams[?lastEventTimestamp > `'$start_time'`].logStreamName' \
        --output text 2>/dev/null)
    
    if [ -z "$streams" ]; then
        echo -e "${YELLOW}⚠️  No recent log streams found.${NC}"
        return
    fi
    
    # Get logs from each stream
    for stream in $streams; do
        echo -e "${GREEN}📄 Log Stream: $stream${NC}"
        echo "----------------------------------------"
        get_logs_from_stream "$stream" "$start_time"
        echo ""
    done
}

# Function to get the latest logs (last 10 minutes by default)
get_latest_logs() {
    echo -e "${YELLOW}📋 Fetching latest logs...${NC}"
    echo ""
    
    local latest_stream=$(get_latest_log_stream)
    
    if [ "$latest_stream" = "None" ] || [ -z "$latest_stream" ]; then
        echo -e "${YELLOW}⚠️  No log streams found.${NC}"
        return
    fi
    
    echo -e "${GREEN}📄 Latest Log Stream: $latest_stream${NC}"
    echo "----------------------------------------"
    
    # Get the last 50 events from the latest stream
    aws logs get-log-events \
        --log-group-name "$LOG_GROUP_NAME" \
        --log-stream-name "$latest_stream" \
        --region "$REGION" \
        --start-from-head false \
        --limit 50 \
        --query 'events[*].[timestamp,message]' \
        --output table 2>/dev/null
}

# Function to follow logs in real-time
follow_logs() {
    echo -e "${YELLOW}👀 Following logs in real-time (Ctrl+C to stop)...${NC}"
    echo ""
    
    # Get the latest stream
    local latest_stream=$(get_latest_log_stream)
    
    if [ "$latest_stream" = "None" ] || [ -z "$latest_stream" ]; then
        echo -e "${YELLOW}⚠️  No log streams found.${NC}"
        return
    fi
    
    echo -e "${GREEN}📄 Following Log Stream: $latest_stream${NC}"
    echo "----------------------------------------"
    
    # Get the current timestamp
    local start_time=$(date +%s)000
    
    # Follow logs
    aws logs tail "$LOG_GROUP_NAME" \
        --region "$REGION" \
        --since 1m \
        --follow 2>/dev/null
}

# Function to search for specific patterns
search_logs() {
    local pattern="$1"
    local minutes="${2:-60}"
    local start_time=$(($(date +%s) - (minutes * 60)))000
    
    echo -e "${YELLOW}🔍 Searching for pattern: '$pattern' in the last $minutes minutes...${NC}"
    echo ""
    
    # Get all log streams
    local streams=$(aws logs describe-log-streams \
        --log-group-name "$LOG_GROUP_NAME" \
        --region "$REGION" \
        --order-by LastEventTime \
        --descending \
        --query 'logStreams[?lastEventTimestamp > `'$start_time'`].logStreamName' \
        --output text 2>/dev/null)
    
    if [ -z "$streams" ]; then
        echo -e "${YELLOW}⚠️  No recent log streams found.${NC}"
        return
    fi
    
    # Search in each stream
    for stream in $streams; do
        echo -e "${GREEN}📄 Searching in: $stream${NC}"
        echo "----------------------------------------"
        
        aws logs get-log-events \
            --log-group-name "$LOG_GROUP_NAME" \
            --log-stream-name "$stream" \
            --region "$REGION" \
            --start-time "$start_time" \
            --query 'events[?contains(message, `'$pattern'`)][timestamp,message]' \
            --output table 2>/dev/null
        echo ""
    done
}

# Function to show log statistics
show_stats() {
    echo -e "${YELLOW}📊 Log Statistics${NC}"
    echo "----------------------------------------"
    
    # Get log group info
    local log_group_info=$(aws logs describe-log-groups \
        --log-group-name-prefix "$LOG_GROUP_NAME" \
        --region "$REGION" \
        --query 'logGroups[0]' 2>/dev/null)
    
    if [ "$log_group_info" = "None" ] || [ -z "$log_group_info" ]; then
        echo -e "${YELLOW}⚠️  Log group not found.${NC}"
        return
    fi
    
    echo -e "${GREEN}Log Group:${NC} $LOG_GROUP_NAME"
    echo -e "${GREEN}Stored Bytes:${NC} $(echo "$log_group_info" | jq -r '.storedBytes // "N/A"')"
    echo -e "${GREEN}Metric Filter Count:${NC} $(echo "$log_group_info" | jq -r '.metricFilterCount // "N/A"')"
    echo -e "${GREEN}Creation Time:${NC} $(echo "$log_group_info" | jq -r '.creationTime // "N/A" | strftime("%Y-%m-%d %H:%M:%S")')"
    echo ""
    
    # Get recent log streams count
    local recent_streams=$(aws logs describe-log-streams \
        --log-group-name "$LOG_GROUP_NAME" \
        --region "$REGION" \
        --order-by LastEventTime \
        --descending \
        --max-items 10 \
        --query 'logStreams[0:10].logStreamName' \
        --output text 2>/dev/null)
    
    echo -e "${GREEN}Recent Log Streams:${NC}"
    if [ -z "$recent_streams" ]; then
        echo "  No streams found"
    else
        echo "$recent_streams" | tr '\t' '\n' | sed 's/^/  /'
    fi
}

# Main menu
show_menu() {
    echo -e "${BLUE}Choose an option:${NC}"
    echo "1) Get latest logs (last 50 events)"
    echo "2) Get recent logs (last 10 minutes)"
    echo "3) Get recent logs (custom minutes)"
    echo "4) Follow logs in real-time"
    echo "5) Search for specific pattern"
    echo "6) Show log statistics"
    echo "7) Exit"
    echo ""
}

# Main script logic
main() {
    case "${1:-}" in
        "latest"|"1")
            get_latest_logs
            ;;
        "recent"|"2")
            get_recent_logs 10
            ;;
        "custom"|"3")
            read -p "Enter number of minutes: " minutes
            get_recent_logs "$minutes"
            ;;
        "follow"|"4")
            follow_logs
            ;;
        "search"|"5")
            if [ -z "$2" ]; then
                read -p "Enter search pattern: " pattern
            else
                pattern="$2"
            fi
            search_logs "$pattern"
            ;;
        "stats"|"6")
            show_stats
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [option] [pattern]"
            echo ""
            echo "Options:"
            echo "  latest, 1    Get latest logs (last 50 events)"
            echo "  recent, 2    Get recent logs (last 10 minutes)"
            echo "  custom, 3    Get recent logs (custom minutes)"
            echo "  follow, 4    Follow logs in real-time"
            echo "  search, 5    Search for specific pattern"
            echo "  stats, 6     Show log statistics"
            echo "  help         Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 latest"
            echo "  $0 recent"
            echo "  $0 search 'ERROR'"
            echo "  $0 follow"
            ;;
        "")
            show_menu
            read -p "Enter your choice (1-7): " choice
            case "$choice" in
                1) get_latest_logs ;;
                2) get_recent_logs 10 ;;
                3) 
                    read -p "Enter number of minutes: " minutes
                    get_recent_logs "$minutes"
                    ;;
                4) follow_logs ;;
                5) 
                    read -p "Enter search pattern: " pattern
                    search_logs "$pattern"
                    ;;
                6) show_stats ;;
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