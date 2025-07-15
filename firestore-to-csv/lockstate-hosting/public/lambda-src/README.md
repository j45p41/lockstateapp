# LockState Lambda - Automation Scripts

This directory contains automation scripts for deploying and monitoring the LockState Lambda function for Alexa integration.

## 📁 Files Overview

- `index.mjs` - Main Lambda function code
- `package.json` - Node.js dependencies
- `lockstate-e72fc-66f29588f54f.json` - Firebase service account key
- `deploy-lambda.sh` - Simple deployment script
- `check-logs.sh` - Comprehensive log monitoring script
- `quick-logs.sh` - Quick log checking script
- `deploy-and-monitor.sh` - All-in-one deployment and monitoring script

## 🚀 Quick Start

### Prerequisites

1. **AWS CLI** installed and configured
   ```bash
   aws configure
   ```

2. **Required permissions** for:
   - Lambda: `lambda:UpdateFunctionCode`, `lambda:GetFunction`
   - CloudWatch Logs: `logs:DescribeLogStreams`, `logs:GetLogEvents`, `logs:Tail`

### Basic Usage

#### 1. Deploy and Monitor (Recommended)
```bash
./deploy-and-monitor.sh deploy-monitor
```
This will:
- Deploy the latest code
- Wait for deployment to complete
- Show function information
- Start real-time log monitoring

#### 2. Quick Log Check
```bash
./quick-logs.sh
```
Shows the last 20 log events from the latest stream.

#### 3. Deploy Only
```bash
./deploy-and-monitor.sh deploy
```

## 📋 Script Details

### `deploy-and-monitor.sh` - All-in-One Script

**Features:**
- ✅ Prerequisites checking
- ✅ Lambda deployment
- ✅ Real-time log monitoring
- ✅ Error searching
- ✅ Function information display

**Usage:**
```bash
# Interactive menu
./deploy-and-monitor.sh

# Direct commands
./deploy-and-monitor.sh deploy-monitor  # Deploy and monitor
./deploy-and-monitor.sh deploy          # Deploy only
./deploy-and-monitor.sh monitor         # Monitor logs only
./deploy-and-monitor.sh logs            # Show recent logs
./deploy-and-monitor.sh errors          # Search for errors
./deploy-and-monitor.sh info            # Show function info
```

### `check-logs.sh` - Comprehensive Log Monitoring

**Features:**
- 📊 Log statistics
- 🔍 Pattern searching
- ⏰ Time-based filtering
- 📄 Multi-stream support
- 👀 Real-time following

**Usage:**
```bash
# Interactive menu
./check-logs.sh

# Direct commands
./check-logs.sh latest    # Latest 50 events
./check-logs.sh recent    # Last 10 minutes
./check-logs.sh custom    # Custom time range
./check-logs.sh follow    # Real-time monitoring
./check-logs.sh search    # Search for patterns
./check-logs.sh stats     # Log statistics
```

### `quick-logs.sh` - Simple Log Checker

**Features:**
- ⚡ Fast execution
- 📄 Latest 20 events
- 🎯 Simple output

**Usage:**
```bash
./quick-logs.sh
```

### `deploy-lambda.sh` - Simple Deployment

**Features:**
- 📦 Creates deployment package
- 🚀 Updates Lambda function
- 🧹 Cleans up temporary files

**Usage:**
```bash
./deploy-lambda.sh
```

## 🔧 Configuration

### Lambda Function Settings
- **Function Name:** `lockstate-lambda`
- **Region:** `eu-west-1`
- **Runtime:** Node.js 18.x
- **Handler:** `index.handler`

### Environment Variables
The Lambda function expects these environment variables:
- `ALEXA_CLIENT_ID` - Alexa skill client ID
- `ALEXA_CLIENT_SECRET` - Alexa skill client secret
- `TOKEN_LOOKUP_URL` - URL for token lookup endpoint
- `LWA_AUTH_URL` - Amazon Login with Amazon auth URL
- `LWA_TOKEN_URL` - Amazon Login with Amazon token URL

## 📊 Monitoring Workflow

### For Alexa Account Linking Debugging

1. **Deploy and monitor:**
   ```bash
   ./deploy-and-monitor.sh deploy-monitor
   ```

2. **Test Alexa account linking** in the Alexa app

3. **Watch logs in real-time** to see:
   - `/alexaAuth` requests
   - `/alexaToken` requests
   - Amazon token exchanges
   - Firestore operations

4. **Search for errors:**
   ```bash
   ./deploy-and-monitor.sh errors
   ```

### For General Monitoring

1. **Quick check:**
   ```bash
   ./quick-logs.sh
   ```

2. **Recent activity:**
   ```bash
   ./deploy-and-monitor.sh logs
   ```

3. **Real-time monitoring:**
   ```bash
   ./deploy-and-monitor.sh monitor
   ```

## 🐛 Troubleshooting

### Common Issues

1. **AWS CLI not configured**
   ```bash
   aws configure
   ```

2. **Permission denied**
   - Ensure your AWS user has the required permissions
   - Check IAM policies for Lambda and CloudWatch Logs access

3. **No logs found**
   - The Lambda function might not have been invoked recently
   - Check if the function name is correct in the scripts

4. **Deployment fails**
   - Check if the function exists in AWS Lambda
   - Verify the region is correct
   - Ensure all required files are present

### Debug Commands

```bash
# Check AWS identity
aws sts get-caller-identity

# List Lambda functions
aws lambda list-functions --region eu-west-1

# Check function status
aws lambda get-function --function-name lockstate-lambda --region eu-west-1

# List log groups
aws logs describe-log-groups --region eu-west-1
```

## 📝 Log Analysis

### Key Log Patterns

- **Alexa Auth Flow:**
  - `=== /alexaAuth branch entered ===`
  - `=== PHASE 1: Redirecting to Amazon ===`
  - `=== PHASE 2: Amazon redirected back with code ===`

- **Token Exchange:**
  - `=== /alexaToken branch entered ===`
  - `Looking up code in Firestore:`
  - `Amazon token exchange response status:`

- **Errors:**
  - `ERROR` - General errors
  - `invalid_grant` - OAuth errors
  - `Token lookup failed` - Token exchange issues

### Example Log Analysis

```bash
# Search for Alexa auth requests
./check-logs.sh search "alexaAuth"

# Search for token exchanges
./check-logs.sh search "alexaToken"

# Search for errors
./check-logs.sh search "ERROR"

# Monitor in real-time during testing
./deploy-and-monitor.sh monitor
```

## 🔄 Workflow Integration

### Development Workflow

1. **Make code changes** to `index.mjs`
2. **Deploy and monitor:**
   ```bash
   ./deploy-and-monitor.sh deploy-monitor
   ```
3. **Test the changes** in Alexa app
4. **Watch logs** for any issues
5. **Iterate** if needed

### Testing Workflow

1. **Deploy latest code:**
   ```bash
   ./deploy-and-monitor.sh deploy
   ```
2. **Start monitoring:**
   ```bash
   ./deploy-and-monitor.sh monitor
   ```
3. **Perform test** (Alexa account linking, voice commands, etc.)
4. **Analyze logs** for success/errors
5. **Search for specific issues:**
   ```bash
   ./deploy-and-monitor.sh errors
   ```

## 📞 Support

If you encounter issues:

1. **Check the logs** using the provided scripts
2. **Verify AWS configuration** and permissions
3. **Ensure all environment variables** are set correctly
4. **Test with the Alexa app** to reproduce the issue

The scripts provide comprehensive logging and monitoring capabilities to help debug any issues with the Alexa integration. 