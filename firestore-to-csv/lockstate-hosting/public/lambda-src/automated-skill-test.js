#!/usr/bin/env node

/**
 * Automated Alexa Skill Lifecycle Test
 * Tests the complete flow: account linking → discovery → state reporting
 */

import { LambdaClient, InvokeCommand } from '@aws-sdk/client-lambda';
import fs from 'fs';

const lambda = new LambdaClient({ region: 'eu-west-1' });
const FUNCTION_NAME = 'locksureSmartHomeProxy';

// Test configuration
const TEST_CONFIG = {
  iterations: 5,
  delayBetweenTests: 2000, // 2 seconds
  testUid: '6ue1XtW8cndXJQyHydNo86PW1p43',
  testRoomId: 'RcW0lotdwT3Eq4fCvuKw'
};

// Test results storage
const testResults = {
  totalTests: 0,
  passedTests: 0,
  failedTests: 0,
  details: []
};

// Helper function to delay execution
const delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));

// Helper function to log with timestamp
const log = (message) => {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] ${message}`);
};

// Helper function to invoke Lambda
async function invokeLambda(payload) {
  try {
    const command = new InvokeCommand({
      FunctionName: FUNCTION_NAME,
      Payload: JSON.stringify(payload),
      InvocationType: 'RequestResponse'
    });
    
    const response = await lambda.send(command);
    const result = JSON.parse(Buffer.from(response.Payload).toString());
    return { success: true, data: result };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

// Test 1: Account Linking Simulation
async function testAccountLinking() {
  log('🧪 Testing Account Linking...');
  
  const tokenPayload = {
    directive: {
      header: {
        namespace: 'Alexa.Authorization',
        name: 'AcceptGrant',
        payloadVersion: '3',
        messageId: 'test-auth-' + Date.now()
      },
      payload: {
        grant: {
          type: 'OAuth2.AuthorizationCode',
          code: TEST_CONFIG.testUid // Using UID as code
        },
        grantee: {
          type: 'BearerToken',
          token: TEST_CONFIG.testUid
        }
      }
    }
  };
  
  const result = await invokeLambda(tokenPayload);
  
  if (result.success) {
    log('✅ Account linking test completed');
    return true;
  } else {
    log(`❌ Account linking failed: ${result.error}`);
    return false;
  }
}

// Test 2: Device Discovery
async function testDeviceDiscovery() {
  log('🔍 Testing Device Discovery...');
  
  const discoveryPayload = {
    directive: {
      header: {
        namespace: 'Alexa.Discovery',
        name: 'Discover',
        payloadVersion: '3',
        messageId: 'test-discovery-' + Date.now()
      },
      payload: {
        scope: {
          type: 'BearerToken',
          token: TEST_CONFIG.testUid
        }
      }
    }
  };
  
  const result = await invokeLambda(discoveryPayload);
  
  if (result.success && result.data.event && result.data.event.payload.endpoints) {
    const endpoints = result.data.event.payload.endpoints;
    log(`✅ Discovery found ${endpoints.length} devices`);
    
    // Verify the test room is present
    const testRoom = endpoints.find(ep => ep.endpointId === TEST_CONFIG.testRoomId);
    if (testRoom) {
      log(`✅ Test room "${testRoom.friendlyName}" found`);
      return true;
    } else {
      log(`❌ Test room not found in discovery response`);
      return false;
    }
  } else {
    log(`❌ Discovery failed: ${result.error || 'Invalid response format'}`);
    return false;
  }
}

// Test 3: State Reporting
async function testStateReporting() {
  log('📊 Testing State Reporting...');
  
  const statePayload = {
    directive: {
      header: {
        namespace: 'Alexa',
        name: 'ReportState',
        payloadVersion: '3',
        messageId: 'test-state-' + Date.now(),
        correlationToken: 'test-correlation-' + Date.now()
      },
      endpoint: {
        scope: {
          type: 'BearerToken',
          token: TEST_CONFIG.testUid
        },
        endpointId: TEST_CONFIG.testRoomId
      },
      payload: {}
    }
  };
  
  const result = await invokeLambda(statePayload);
  
  if (result.success && result.data.context && result.data.context.properties) {
    const properties = result.data.context.properties;
    const lockState = properties.find(p => p.namespace === 'Alexa.LockController' && p.name === 'lockState');
    
    if (lockState) {
      log(`✅ State report successful: ${lockState.value}`);
      return true;
    } else {
      log(`❌ Lock state not found in response`);
      return false;
    }
  } else {
    log(`❌ State reporting failed: ${result.error || 'Invalid response format'}`);
    return false;
  }
}

// Test 4: Lock Command (should be unsupported)
async function testLockCommand() {
  log('🔒 Testing Lock Command (should be unsupported)...');
  
  const lockPayload = {
    directive: {
      header: {
        namespace: 'Alexa.LockController',
        name: 'Lock',
        payloadVersion: '3',
        messageId: 'test-lock-' + Date.now()
      },
      endpoint: {
        scope: {
          type: 'BearerToken',
          token: TEST_CONFIG.testUid
        },
        endpointId: TEST_CONFIG.testRoomId
      },
      payload: {}
    }
  };
  
  const result = await invokeLambda(lockPayload);
  
  // This should return an error response since we don't implement Lock command
  if (result.success && result.data.event && result.data.event.header.name === 'ErrorResponse') {
    log(`✅ Lock command correctly returned error (as expected)`);
    return true;
  } else {
    log(`❌ Lock command should have returned error but didn't`);
    return false;
  }
}

// Complete lifecycle test
async function runLifecycleTest(iteration) {
  log(`\n🔄 Starting Lifecycle Test #${iteration}`);
  log('=' .repeat(50));
  
  const testResult = {
    iteration,
    timestamp: new Date().toISOString(),
    tests: {}
  };
  
  // Test 1: Account Linking
  testResult.tests.accountLinking = await testAccountLinking();
  await delay(500);
  
  // Test 2: Device Discovery
  testResult.tests.discovery = await testDeviceDiscovery();
  await delay(500);
  
  // Test 3: State Reporting
  testResult.tests.stateReporting = await testStateReporting();
  await delay(500);
  
  // Test 4: Lock Command
  testResult.tests.lockCommand = await testLockCommand();
  
  // Calculate overall result
  const passedTests = Object.values(testResult.tests).filter(Boolean).length;
  const totalTests = Object.keys(testResult.tests).length;
  testResult.overall = passedTests === totalTests;
  
  log(`📈 Test #${iteration} Results: ${passedTests}/${totalTests} passed`);
  
  if (testResult.overall) {
    log(`✅ Test #${iteration} PASSED`);
    testResults.passedTests++;
  } else {
    log(`❌ Test #${iteration} FAILED`);
    testResults.failedTests++;
  }
  
  testResults.totalTests++;
  testResults.details.push(testResult);
  
  return testResult.overall;
}

// Main test runner
async function runAutomatedTests() {
  log('🚀 Starting Automated Alexa Skill Lifecycle Tests');
  log(`📋 Configuration: ${TEST_CONFIG.iterations} iterations, ${TEST_CONFIG.delayBetweenTests}ms delay`);
  log('=' .repeat(60));
  
  const startTime = Date.now();
  
  for (let i = 1; i <= TEST_CONFIG.iterations; i++) {
    const success = await runLifecycleTest(i);
    
    if (i < TEST_CONFIG.iterations) {
      log(`⏳ Waiting ${TEST_CONFIG.delayBetweenTests}ms before next test...`);
      await delay(TEST_CONFIG.delayBetweenTests);
    }
  }
  
  const endTime = Date.now();
  const duration = (endTime - startTime) / 1000;
  
  // Generate summary report
  log('\n' + '=' .repeat(60));
  log('📊 FINAL TEST SUMMARY');
  log('=' .repeat(60));
  log(`Total Tests: ${testResults.totalTests}`);
  log(`Passed: ${testResults.passedTests}`);
  log(`Failed: ${testResults.failedTests}`);
  log(`Success Rate: ${((testResults.passedTests / testResults.totalTests) * 100).toFixed(1)}%`);
  log(`Total Duration: ${duration.toFixed(1)}s`);
  
  // Detailed breakdown
  log('\n📋 DETAILED BREAKDOWN:');
  testResults.details.forEach((result, index) => {
    const status = result.overall ? '✅ PASS' : '❌ FAIL';
    log(`Test #${index + 1}: ${status}`);
    
    if (!result.overall) {
      Object.entries(result.tests).forEach(([testName, passed]) => {
        const testStatus = passed ? '✅' : '❌';
        log(`  - ${testName}: ${testStatus}`);
      });
    }
  });
  
  // Save detailed results to file
  const reportFile = `skill-test-report-${new Date().toISOString().replace(/[:.]/g, '-')}.json`;
  fs.writeFileSync(reportFile, JSON.stringify(testResults, null, 2));
  log(`\n📄 Detailed report saved to: ${reportFile}`);
  
  // Final verdict
  if (testResults.failedTests === 0) {
    log('\n🎉 ALL TESTS PASSED! The skill is working consistently.');
    process.exit(0);
  } else {
    log('\n⚠️  SOME TESTS FAILED! There are inconsistencies in the skill behavior.');
    process.exit(1);
  }
}

// Run the tests
runAutomatedTests().catch(error => {
  log(`💥 Test execution failed: ${error.message}`);
  process.exit(1);
}); 