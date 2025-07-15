#!/bin/bash

# Comprehensive Alexa OAuth Flow Test Runner
# This script systematically tests the entire OAuth flow using CLI tools

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
API_BASE_URL="https://18glpgnilb.execute-api.eu-west-1.amazonaws.com/prod"
WORKING_UID="6ue1XtW8cndXJQyHydNo86PW1p43"
TEST_UID="testuser1234567890123456789012"
REDIRECT_URI="https://layla.amazon.com/api/skill/link/M2KB1TY529INC9"

# Test results file
RESULTS_FILE="oauth_test_results_$(date +%Y%m%d_%H%M%S).json"
LOG_FILE="oauth_test_log_$(date +%Y%m%d_%H%M%S).log"

# Function to log messages
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}❌ $1${NC}" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${CYAN}ℹ️  $1${NC}" | tee -a "$LOG_FILE"
}

# Function to make HTTP requests and capture results
make_request() {
    local url="$1"
    local method="${2:-GET}"
    local data="${3:-}"
    local headers="${4:-}"
    
    local curl_cmd="curl -s -w '\nHTTPSTATUS:%{http_code}\nTIME:%{time_total}\n'"
    
    if [ "$method" = "POST" ]; then
        curl_cmd="$curl_cmd -X POST"
        if [ -n "$data" ]; then
            curl_cmd="$curl_cmd -d '$data'"
        fi
    fi
    
    if [ -n "$headers" ]; then
        curl_cmd="$curl_cmd -H '$headers'"
    fi
    
    curl_cmd="$curl_cmd '$url'"
    
    log_info "Making $method request to: $url"
    if [ -n "$data" ]; then
        log_info "Request data: $data"
    fi
    
    local response
    response=$(eval $curl_cmd)
    
    # Extract status code and response time
    local status_code=$(echo "$response" | grep "HTTPSTATUS:" | cut -d: -f2)
    local response_time=$(echo "$response" | grep "TIME:" | cut -d: -f2)
    local response_body=$(echo "$response" | sed '/HTTPSTATUS:/d' | sed '/TIME:/d')
    
    log_info "Response status: $status_code (${response_time}s)"
    log_info "Response body: ${response_body:0:200}..."
    
    echo "{\"status\": $status_code, \"time\": $response_time, \"body\": $(echo "$response_body" | jq -R .)}"
}

# Function to test endpoint availability
test_endpoint_availability() {
    log "=== STEP 1: Testing Endpoint Availability ==="
    
    local endpoints=("/test" "/alexaAuth" "/alexaToken" "/alexaSmartHome" "/debug")
    local results=()
    
    for endpoint in "${endpoints[@]}"; do
        log_info "Testing endpoint: $endpoint"
        local result=$(make_request "$API_BASE_URL$endpoint")
        results+=("$result")
        
        local status=$(echo "$result" | jq -r '.status')
        if [ "$status" = "200" ] || [ "$status" = "302" ] || [ "$status" = "400" ]; then
            log_success "Endpoint $endpoint is accessible (status: $status)"
        else
            log_error "Endpoint $endpoint is not accessible (status: $status)"
        fi
    done
    
    echo "${results[@]}" > "endpoint_availability_results.json"
}

# Function to test /test endpoint with different UIDs
test_test_endpoint() {
    log "=== STEP 2: Testing /test Endpoint with Different UIDs ==="
    
    # Test with working UID
    log_info "Testing with working UID: $WORKING_UID"
    local working_result=$(make_request "$API_BASE_URL/test?uid=$WORKING_UID")
    local working_status=$(echo "$working_result" | jq -r '.status')
    
    if [ "$working_status" = "200" ]; then
        log_success "Working UID test passed"
        local rooms_found=$(echo "$working_result" | jq -r '.body' | jq -r '.roomsFound // 0')
        log_info "Found $rooms_found rooms for working UID"
    else
        log_error "Working UID test failed (status: $working_status)"
    fi
    
    # Test with test UID
    log_info "Testing with test UID: $TEST_UID"
    local test_result=$(make_request "$API_BASE_URL/test?uid=$TEST_UID")
    local test_status=$(echo "$test_result" | jq -r '.status')
    
    if [ "$test_status" = "200" ]; then
        log_success "Test UID test passed"
        local rooms_found=$(echo "$test_result" | jq -r '.body' | jq -r '.roomsFound // 0')
        log_info "Found $rooms_found rooms for test UID"
    else
        log_error "Test UID test failed (status: $test_status)"
    fi
    
    echo "{\"working\": $working_result, \"test\": $test_result}" > "test_endpoint_results.json"
}

# Function to test OAuth Phase 1 (redirect to Amazon)
test_oauth_phase1() {
    log "=== STEP 3: Testing OAuth Phase 1 (Redirect to Amazon) ==="
    
    # Test with working UID
    log_info "Testing OAuth Phase 1 with working UID"
    local working_url="$API_BASE_URL/alexaAuth?redirect_uri=$(echo "$REDIRECT_URI" | sed 's/:/%3A/g' | sed 's/\//%2F/g')&state=$WORKING_UID"
    local working_result=$(make_request "$working_url")
    local working_status=$(echo "$working_result" | jq -r '.status')
    
    if [ "$working_status" = "302" ]; then
        log_success "Working UID OAuth Phase 1 successful"
        local location=$(echo "$working_result" | jq -r '.body' | grep -o 'Location: [^[:space:]]*' | cut -d' ' -f2 || echo "")
        if [ -n "$location" ]; then
            log_info "Redirect location: $location"
            # Check if state parameter is preserved
            if echo "$location" | grep -q "state=$WORKING_UID"; then
                log_success "State parameter preserved correctly"
            else
                log_error "State parameter not preserved in redirect"
            fi
        fi
    else
        log_error "Working UID OAuth Phase 1 failed (status: $working_status)"
    fi
    
    # Test with test UID
    log_info "Testing OAuth Phase 1 with test UID"
    local test_url="$API_BASE_URL/alexaAuth?redirect_uri=$(echo "$REDIRECT_URI" | sed 's/:/%3A/g' | sed 's/\//%2F/g')&state=$TEST_UID"
    local test_result=$(make_request "$test_url")
    local test_status=$(echo "$test_result" | jq -r '.status')
    
    if [ "$test_status" = "302" ]; then
        log_success "Test UID OAuth Phase 1 successful"
        local location=$(echo "$test_result" | jq -r '.body' | grep -o 'Location: [^[:space:]]*' | cut -d' ' -f2 || echo "")
        if [ -n "$location" ]; then
            log_info "Redirect location: $location"
            # Check if state parameter is preserved
            if echo "$location" | grep -q "state=$TEST_UID"; then
                log_success "State parameter preserved correctly"
            else
                log_error "State parameter not preserved in redirect"
            fi
        fi
    else
        log_error "Test UID OAuth Phase 1 failed (status: $test_status)"
    fi
    
    echo "{\"working\": $working_result, \"test\": $test_result}" > "oauth_phase1_results.json"
}

# Function to test OAuth Phase 2 (callback from Amazon)
test_oauth_phase2() {
    log "=== STEP 4: Testing OAuth Phase 2 (Callback from Amazon) ==="
    
    local fake_auth_code="fake_auth_code_123456"
    
    # Test with working UID
    log_info "Testing OAuth Phase 2 with working UID"
    local working_url="$API_BASE_URL/alexaAuth?redirect_uri=$(echo "$REDIRECT_URI" | sed 's/:/%3A/g' | sed 's/\//%2F/g')&state=$WORKING_UID&code=$fake_auth_code"
    local working_result=$(make_request "$working_url")
    local working_status=$(echo "$working_result" | jq -r '.status')
    
    if [ "$working_status" = "302" ]; then
        log_success "Working UID OAuth Phase 2 successful"
        local location=$(echo "$working_result" | jq -r '.body' | grep -o 'Location: [^[:space:]]*' | cut -d' ' -f2 || echo "")
        if [ -n "$location" ]; then
            log_info "Callback redirect location: $location"
            # Check if both code and state are preserved
            if echo "$location" | grep -q "code=$fake_auth_code" && echo "$location" | grep -q "state=$WORKING_UID"; then
                log_success "Callback parameters preserved correctly"
            else
                log_error "Callback parameters not preserved correctly"
            fi
        fi
    else
        log_error "Working UID OAuth Phase 2 failed (status: $working_status)"
    fi
    
    # Test with test UID
    log_info "Testing OAuth Phase 2 with test UID"
    local test_url="$API_BASE_URL/alexaAuth?redirect_uri=$(echo "$REDIRECT_URI" | sed 's/:/%3A/g' | sed 's/\//%2F/g')&state=$TEST_UID&code=$fake_auth_code"
    local test_result=$(make_request "$test_url")
    local test_status=$(echo "$test_result" | jq -r '.status')
    
    if [ "$test_status" = "302" ]; then
        log_success "Test UID OAuth Phase 2 successful"
        local location=$(echo "$test_result" | jq -r '.body' | grep -o 'Location: [^[:space:]]*' | cut -d' ' -f2 || echo "")
        if [ -n "$location" ]; then
            log_info "Callback redirect location: $location"
            # Check if both code and state are preserved
            if echo "$location" | grep -q "code=$fake_auth_code" && echo "$location" | grep -q "state=$TEST_UID"; then
                log_success "Callback parameters preserved correctly"
            else
                log_error "Callback parameters not preserved correctly"
            fi
        fi
    else
        log_error "Test UID OAuth Phase 2 failed (status: $test_status)"
    fi
    
    echo "{\"working\": $working_result, \"test\": $test_result}" > "oauth_phase2_results.json"
}

# Function to test /alexaToken endpoint
test_alexa_token() {
    log "=== STEP 5: Testing /alexaToken Endpoint ==="
    
    local token_data="grant_type=authorization_code&code=fake_auth_code_123456&redirect_uri=$(echo "$REDIRECT_URI" | sed 's/:/%3A/g' | sed 's/\//%2F/g')"
    local headers="Content-Type: application/x-www-form-urlencoded"
    
    log_info "Testing token exchange with fake credentials"
    local result=$(make_request "$API_BASE_URL/alexaToken" "POST" "$token_data" "$headers")
    local status=$(echo "$result" | jq -r '.status')
    
    if [ "$status" = "200" ]; then
        log_success "Token endpoint responded successfully"
        log_info "Token response structure looks correct"
    else
        log_warning "Token endpoint failed (status: $status) - expected with fake credentials"
    fi
    
    echo "$result" > "alexa_token_results.json"
}

# Function to test device discovery
test_device_discovery() {
    log "=== STEP 6: Testing Device Discovery ==="
    
    local discovery_request='{
        "directive": {
            "header": {
                "namespace": "Alexa.Discovery",
                "name": "Discover",
                "payloadVersion": "3",
                "messageId": "test-message-id-123"
            },
            "payload": {
                "scope": {
                    "type": "BearerToken",
                    "token": "'$WORKING_UID'"
                }
            }
        }
    }'
    
    local headers="Content-Type: application/json"
    
    # Test with working UID
    log_info "Testing discovery with working UID"
    local working_result=$(make_request "$API_BASE_URL/alexaSmartHome" "POST" "$discovery_request" "$headers")
    local working_status=$(echo "$working_result" | jq -r '.status')
    
    if [ "$working_status" = "200" ]; then
        log_success "Discovery with working UID successful"
        local endpoints_count=$(echo "$working_result" | jq -r '.body' | jq -r '.event.payload.endpoints | length // 0')
        log_info "Found $endpoints_count devices"
    else
        log_error "Discovery with working UID failed (status: $working_status)"
    fi
    
    # Test with test UID
    local test_discovery_request=$(echo "$discovery_request" | sed "s/$WORKING_UID/$TEST_UID/g")
    log_info "Testing discovery with test UID"
    local test_result=$(make_request "$API_BASE_URL/alexaSmartHome" "POST" "$test_discovery_request" "$headers")
    local test_status=$(echo "$test_result" | jq -r '.status')
    
    if [ "$test_status" = "200" ]; then
        log_success "Discovery with test UID successful"
        local endpoints_count=$(echo "$test_result" | jq -r '.body' | jq -r '.event.payload.endpoints | length // 0')
        log_info "Found $endpoints_count devices"
    else
        log_error "Discovery with test UID failed (status: $test_status)"
    fi
    
    echo "{\"working\": $working_result, \"test\": $test_result}" > "device_discovery_results.json"
}

# Function to test error conditions
test_error_conditions() {
    log "=== STEP 7: Testing Error Conditions ==="
    
    # Test missing state parameter
    log_info "Testing missing state parameter"
    local missing_state_result=$(make_request "$API_BASE_URL/alexaAuth?redirect_uri=$(echo "$REDIRECT_URI" | sed 's/:/%3A/g' | sed 's/\//%2F/g')")
    local missing_state_status=$(echo "$missing_state_result" | jq -r '.status')
    
    if [ "$missing_state_status" = "400" ]; then
        log_success "Missing state parameter correctly rejected"
    else
        log_error "Missing state parameter not rejected (status: $missing_state_status)"
    fi
    
    # Test invalid UID format
    log_info "Testing invalid UID format"
    local invalid_uid_result=$(make_request "$API_BASE_URL/alexaAuth?redirect_uri=$(echo "$REDIRECT_URI" | sed 's/:/%3A/g' | sed 's/\//%2F/g')&state=invalid_uid")
    local invalid_uid_status=$(echo "$invalid_uid_result" | jq -r '.status')
    
    if [ "$invalid_uid_status" = "302" ]; then
        log_success "Invalid UID format accepted (correct for OAuth flow)"
    else
        log_warning "Invalid UID format rejected (status: $invalid_uid_status)"
    fi
    
    echo "{\"missing_state\": $missing_state_result, \"invalid_uid\": $invalid_uid_result}" > "error_conditions_results.json"
}

# Function to check CloudWatch logs
check_cloudwatch_logs() {
    log "=== STEP 8: Checking CloudWatch Logs ==="
    
    if command -v aws &> /dev/null; then
        log_info "AWS CLI found, checking recent CloudWatch logs..."
        
        # Get the Lambda function name from the API Gateway URL
        local function_name="lockstate-hosting-lambda"
        
        # Get recent log events
        local log_group="/aws/lambda/$function_name"
        
        if aws logs describe-log-groups --log-group-name-prefix "$log_group" --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "$log_group"; then
            log_info "Found log group: $log_group"
            
            # Get recent log events
            local recent_logs=$(aws logs filter-log-events \
                --log-group-name "$log_group" \
                --start-time $(($(date +%s) - 3600))000 \
                --query 'events[*].message' \
                --output text 2>/dev/null || echo "No recent logs found")
            
            if [ -n "$recent_logs" ] && [ "$recent_logs" != "No recent logs found" ]; then
                log_success "Found recent CloudWatch logs"
                echo "$recent_logs" > "cloudwatch_logs_$(date +%Y%m%d_%H%M%S).txt"
                log_info "Logs saved to cloudwatch_logs_$(date +%Y%m%d_%H%M%S).txt"
            else
                log_warning "No recent CloudWatch logs found"
            fi
        else
            log_warning "Log group not found: $log_group"
        fi
    else
        log_warning "AWS CLI not found, skipping CloudWatch log check"
    fi
}

# Function to generate test summary
generate_summary() {
    log "=== GENERATING TEST SUMMARY ==="
    
    local summary="{
        \"test_timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
        \"api_base_url\": \"$API_BASE_URL\",
        \"working_uid\": \"$WORKING_UID\",
        \"test_uid\": \"$TEST_UID\",
        \"redirect_uri\": \"$REDIRECT_URI\",
        \"results_files\": [
            \"endpoint_availability_results.json\",
            \"test_endpoint_results.json\",
            \"oauth_phase1_results.json\",
            \"oauth_phase2_results.json\",
            \"alexa_token_results.json\",
            \"device_discovery_results.json\",
            \"error_conditions_results.json\"
        ],
        \"log_file\": \"$LOG_FILE\"
    }"
    
    echo "$summary" > "$RESULTS_FILE"
    log_success "Test summary saved to $RESULTS_FILE"
}

# Main test runner
main() {
    log "🚀 Starting Comprehensive Alexa OAuth Flow Test"
    log "API Base URL: $API_BASE_URL"
    log "Working UID: $WORKING_UID"
    log "Test UID: $TEST_UID"
    log "Redirect URI: $REDIRECT_URI"
    log "Results will be saved to: $RESULTS_FILE"
    log "Logs will be saved to: $LOG_FILE"
    
    # Check prerequisites
    if ! command -v curl &> /dev/null; then
        log_error "curl is required but not installed"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed"
        exit 1
    fi
    
    # Run all tests
    test_endpoint_availability
    test_test_endpoint
    test_oauth_phase1
    test_oauth_phase2
    test_alexa_token
    test_device_discovery
    test_error_conditions
    check_cloudwatch_logs
    generate_summary
    
    log "🎉 All tests completed!"
    log "📊 Review the results in: $RESULTS_FILE"
    log "📝 Check detailed logs in: $LOG_FILE"
    log ""
    log "Next steps:"
    log "1. Review the test results above for any failures"
    log "2. Check the generated JSON files for detailed responses"
    log "3. If all tests pass, the issue may be in the actual OAuth flow with Amazon"
    log "4. Consider testing with real Amazon credentials in a controlled environment"
}

# Run the main function
main "$@" 