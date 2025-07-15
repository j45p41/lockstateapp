#!/usr/bin/env node

/**
 * Comprehensive Alexa OAuth Flow Test
 * This script tests the entire OAuth flow step by step to identify where the issue occurs
 */

import fetch from 'node-fetch';
import { URLSearchParams } from 'url';

// Configuration
const CONFIG = {
  // Your API Gateway URL
  API_BASE_URL: 'https://18glpgnilb.execute-api.eu-west-1.amazonaws.com/prod',
  
  // Test UIDs - one that works (hardcoded) and one that doesn't (dynamic)
  WORKING_UID: '6ue1XtW8cndXJQyHydNo86PW1p43', // This works
  TEST_UID: 'testuser1234567890123456789012',   // This should work too
  
  // Alexa OAuth settings
  REDIRECT_URI: 'https://layla.amazon.com/api/skill/link/M2KB1TY529INC9',
  
  // Test credentials (replace with real ones)
  TEST_EMAIL: 'test@example.com',
  TEST_PASSWORD: 'testpassword'
};

// Colors for console output
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m'
};

function log(message, color = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

function logStep(step, description) {
  log(`\n${colors.bright}=== STEP ${step}: ${description} ===${colors.reset}`);
}

function logSuccess(message) {
  log(`✅ ${message}`, 'green');
}

function logError(message) {
  log(`❌ ${message}`, 'red');
}

function logWarning(message) {
  log(`⚠️  ${message}`, 'yellow');
}

function logInfo(message) {
  log(`ℹ️  ${message}`, 'blue');
}

// Test utilities
async function makeRequest(url, options = {}) {
  const startTime = Date.now();
  try {
    logInfo(`Making ${options.method || 'GET'} request to: ${url}`);
    if (options.body) {
      logInfo(`Request body: ${options.body}`);
    }
    
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'AlexaOAuthTest/1.0',
        'Accept': 'application/json, text/html, */*',
        ...options.headers
      },
      ...options
    });
    
    const endTime = Date.now();
    const duration = endTime - startTime;
    
    logInfo(`Response status: ${response.status} (${duration}ms)`);
    logInfo(`Response headers: ${JSON.stringify(Object.fromEntries(response.headers.entries()), null, 2)}`);
    
    let responseText;
    const contentType = response.headers.get('content-type') || '';
    
    if (contentType.includes('application/json')) {
      responseText = await response.json();
      logInfo(`Response body (JSON): ${JSON.stringify(responseText, null, 2)}`);
    } else {
      responseText = await response.text();
      logInfo(`Response body (${contentType}): ${responseText.substring(0, 500)}${responseText.length > 500 ? '...' : ''}`);
    }
    
    return {
      status: response.status,
      headers: Object.fromEntries(response.headers.entries()),
      body: responseText,
      duration
    };
  } catch (error) {
    logError(`Request failed: ${error.message}`);
    throw error;
  }
}

// Test 1: Test the /test endpoint with different UIDs
async function testEndpoint() {
  logStep(1, 'Testing /test endpoint with different UIDs');
  
  // Test with working UID
  logInfo('Testing with working UID...');
  const workingResult = await makeRequest(`${CONFIG.API_BASE_URL}/test?uid=${CONFIG.WORKING_UID}`);
  
  if (workingResult.status === 200) {
    logSuccess('Working UID test passed');
    logInfo(`Found ${workingResult.body.roomsFound} rooms for working UID`);
  } else {
    logError('Working UID test failed');
  }
  
  // Test with test UID
  logInfo('Testing with test UID...');
  const testResult = await makeRequest(`${CONFIG.API_BASE_URL}/test?uid=${CONFIG.TEST_UID}`);
  
  if (testResult.status === 200) {
    logSuccess('Test UID test passed');
    logInfo(`Found ${testResult.body.roomsFound} rooms for test UID`);
  } else {
    logError('Test UID test failed');
  }
}

// Test 2: Test /alexaAuth endpoint (Phase 1 - redirect to Amazon)
async function testAlexaAuthPhase1() {
  logStep(2, 'Testing /alexaAuth Phase 1 (redirect to Amazon)');
  
  // Test with working UID
  logInfo('Testing /alexaAuth with working UID...');
  const workingUrl = `${CONFIG.API_BASE_URL}/alexaAuth?redirect_uri=${encodeURIComponent(CONFIG.REDIRECT_URI)}&state=${CONFIG.WORKING_UID}`;
  
  const workingResult = await makeRequest(workingUrl, {
    method: 'GET',
    redirect: 'manual' // Don't follow redirects
  });
  
  if (workingResult.status === 302) {
    logSuccess('Working UID redirect successful');
    const location = workingResult.headers.location;
    logInfo(`Redirect location: ${location}`);
    
    // Parse the redirect URL to check parameters
    const redirectUrl = new URL(location);
    const params = Object.fromEntries(redirectUrl.searchParams.entries());
    logInfo(`Redirect parameters: ${JSON.stringify(params, null, 2)}`);
    
    // Check if state parameter is preserved
    if (params.state === CONFIG.WORKING_UID) {
      logSuccess('State parameter preserved correctly');
    } else {
      logError(`State parameter mismatch. Expected: ${CONFIG.WORKING_UID}, Got: ${params.state}`);
    }
  } else {
    logError(`Working UID redirect failed. Expected 302, got ${workingResult.status}`);
  }
  
  // Test with test UID
  logInfo('Testing /alexaAuth with test UID...');
  const testUrl = `${CONFIG.API_BASE_URL}/alexaAuth?redirect_uri=${encodeURIComponent(CONFIG.REDIRECT_URI)}&state=${CONFIG.TEST_UID}`;
  
  const testResult = await makeRequest(testUrl, {
    method: 'GET',
    redirect: 'manual'
  });
  
  if (testResult.status === 302) {
    logSuccess('Test UID redirect successful');
    const location = testResult.headers.location;
    logInfo(`Redirect location: ${location}`);
    
    // Parse the redirect URL to check parameters
    const redirectUrl = new URL(location);
    const params = Object.fromEntries(redirectUrl.searchParams.entries());
    logInfo(`Redirect parameters: ${JSON.stringify(params, null, 2)}`);
    
    // Check if state parameter is preserved
    if (params.state === CONFIG.TEST_UID) {
      logSuccess('State parameter preserved correctly');
    } else {
      logError(`State parameter mismatch. Expected: ${CONFIG.TEST_UID}, Got: ${params.state}`);
    }
  } else {
    logError(`Test UID redirect failed. Expected 302, got ${testResult.status}`);
  }
}

// Test 3: Test /alexaAuth endpoint (Phase 2 - callback from Amazon)
async function testAlexaAuthPhase2() {
  logStep(3, 'Testing /alexaAuth Phase 2 (callback from Amazon)');
  
  // Simulate Amazon's callback with a fake auth code
  const fakeAuthCode = 'fake_auth_code_123456';
  
  // Test with working UID
  logInfo('Testing callback with working UID...');
  const workingUrl = `${CONFIG.API_BASE_URL}/alexaAuth?redirect_uri=${encodeURIComponent(CONFIG.REDIRECT_URI)}&state=${CONFIG.WORKING_UID}&code=${fakeAuthCode}`;
  
  const workingResult = await makeRequest(workingUrl, {
    method: 'GET',
    redirect: 'manual'
  });
  
  if (workingResult.status === 302) {
    logSuccess('Working UID callback redirect successful');
    const location = workingResult.headers.location;
    logInfo(`Callback redirect location: ${location}`);
    
    // Parse the callback redirect URL
    const redirectUrl = new URL(location);
    const params = Object.fromEntries(redirectUrl.searchParams.entries());
    logInfo(`Callback parameters: ${JSON.stringify(params, null, 2)}`);
    
    // Check if both code and state are preserved
    if (params.code === fakeAuthCode && params.state === CONFIG.WORKING_UID) {
      logSuccess('Callback parameters preserved correctly');
    } else {
      logError('Callback parameters not preserved correctly');
    }
  } else {
    logError(`Working UID callback failed. Expected 302, got ${workingResult.status}`);
  }
  
  // Test with test UID
  logInfo('Testing callback with test UID...');
  const testUrl = `${CONFIG.API_BASE_URL}/alexaAuth?redirect_uri=${encodeURIComponent(CONFIG.REDIRECT_URI)}&state=${CONFIG.TEST_UID}&code=${fakeAuthCode}`;
  
  const testResult = await makeRequest(testUrl, {
    method: 'GET',
    redirect: 'manual'
  });
  
  if (testResult.status === 302) {
    logSuccess('Test UID callback redirect successful');
    const location = testResult.headers.location;
    logInfo(`Callback redirect location: ${location}`);
    
    // Parse the callback redirect URL
    const redirectUrl = new URL(location);
    const params = Object.fromEntries(redirectUrl.searchParams.entries());
    logInfo(`Callback parameters: ${JSON.stringify(params, null, 2)}`);
    
    // Check if both code and state are preserved
    if (params.code === fakeAuthCode && params.state === CONFIG.TEST_UID) {
      logSuccess('Callback parameters preserved correctly');
    } else {
      logError('Callback parameters not preserved correctly');
    }
  } else {
    logError(`Test UID callback failed. Expected 302, got ${testResult.status}`);
  }
}

// Test 4: Test /alexaToken endpoint
async function testAlexaToken() {
  logStep(4, 'Testing /alexaToken endpoint');
  
  const tokenData = {
    grant_type: 'authorization_code',
    code: 'fake_auth_code_123456',
    redirect_uri: CONFIG.REDIRECT_URI
  };
  
  logInfo('Testing token exchange...');
  const result = await makeRequest(`${CONFIG.API_BASE_URL}/alexaToken`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Authorization': 'Basic ' + Buffer.from('fake_client_id:fake_client_secret').toString('base64')
    },
    body: new URLSearchParams(tokenData).toString()
  });
  
  if (result.status === 200) {
    logSuccess('Token endpoint responded successfully');
    logInfo('Token response structure looks correct');
  } else {
    logError(`Token endpoint failed. Status: ${result.status}`);
    logInfo('This is expected since we used fake credentials');
  }
}

// Test 5: Test device discovery
async function testDeviceDiscovery() {
  logStep(5, 'Testing device discovery');
  
  const discoveryRequest = {
    directive: {
      header: {
        namespace: 'Alexa.Discovery',
        name: 'Discover',
        payloadVersion: '3',
        messageId: 'test-message-id-123'
      },
      payload: {
        scope: {
          type: 'BearerToken',
          token: CONFIG.WORKING_UID
        }
      }
    }
  };
  
  logInfo('Testing discovery with working UID...');
  const workingResult = await makeRequest(`${CONFIG.API_BASE_URL}/alexaSmartHome`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(discoveryRequest)
  });
  
  if (workingResult.status === 200) {
    logSuccess('Discovery with working UID successful');
    if (workingResult.body.event && workingResult.body.event.payload.endpoints) {
      logInfo(`Found ${workingResult.body.event.payload.endpoints.length} devices`);
    }
  } else {
    logError(`Discovery with working UID failed. Status: ${workingResult.status}`);
  }
  
  // Test with test UID
  discoveryRequest.directive.payload.scope.token = CONFIG.TEST_UID;
  
  logInfo('Testing discovery with test UID...');
  const testResult = await makeRequest(`${CONFIG.API_BASE_URL}/alexaSmartHome`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(discoveryRequest)
  });
  
  if (testResult.status === 200) {
    logSuccess('Discovery with test UID successful');
    if (testResult.body.event && testResult.body.event.payload.endpoints) {
      logInfo(`Found ${testResult.body.event.payload.endpoints.length} devices`);
    }
  } else {
    logError(`Discovery with test UID failed. Status: ${testResult.status}`);
  }
}

// Test 6: Test error conditions
async function testErrorConditions() {
  logStep(6, 'Testing error conditions');
  
  // Test missing state parameter
  logInfo('Testing missing state parameter...');
  const missingStateResult = await makeRequest(`${CONFIG.API_BASE_URL}/alexaAuth?redirect_uri=${encodeURIComponent(CONFIG.REDIRECT_URI)}`);
  
  if (missingStateResult.status === 400) {
    logSuccess('Missing state parameter correctly rejected');
  } else {
    logError(`Missing state parameter not rejected. Status: ${missingStateResult.status}`);
  }
  
  // Test invalid UID format
  logInfo('Testing invalid UID format...');
  const invalidUidResult = await makeRequest(`${CONFIG.API_BASE_URL}/alexaAuth?redirect_uri=${encodeURIComponent(CONFIG.REDIRECT_URI)}&state=invalid_uid`);
  
  if (invalidUidResult.status === 302) {
    logSuccess('Invalid UID format accepted (this is correct for OAuth flow)');
  } else {
    logWarning(`Invalid UID format rejected. Status: ${invalidUidResult.status}`);
  }
}

// Main test runner
async function runAllTests() {
  log(`${colors.bright}${colors.cyan}🚀 Starting Comprehensive Alexa OAuth Flow Test${colors.reset}\n`);
  log(`API Base URL: ${CONFIG.API_BASE_URL}`);
  log(`Working UID: ${CONFIG.WORKING_UID}`);
  log(`Test UID: ${CONFIG.TEST_UID}`);
  log(`Redirect URI: ${CONFIG.REDIRECT_URI}\n`);
  
  try {
    await testEndpoint();
    await testAlexaAuthPhase1();
    await testAlexaAuthPhase2();
    await testAlexaToken();
    await testDeviceDiscovery();
    await testErrorConditions();
    
    log(`\n${colors.bright}${colors.green}🎉 All tests completed!${colors.reset}`);
    log(`\n${colors.yellow}Next steps:${colors.reset}`);
    log('1. Review the logs above for any failures');
    log('2. Check CloudWatch logs for detailed Lambda execution');
    log('3. If all tests pass, the issue may be in the actual OAuth flow with Amazon');
    log('4. Consider testing with real Amazon credentials in a controlled environment');
    
  } catch (error) {
    logError(`Test suite failed: ${error.message}`);
    console.error(error);
  }
}

// Run the tests if this script is executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
  runAllTests();
}

export { runAllTests, CONFIG }; 