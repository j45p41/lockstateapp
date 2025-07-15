#!/usr/bin/env node

/**
 * Automated UID Testing Framework
 * Tests different approaches to remove hardcoded UID and implement proper account linking
 */

import { LambdaClient, InvokeCommand } from '@aws-sdk/client-lambda';
import fs from 'fs';

const lambda = new LambdaClient({ region: 'eu-west-1' });
const FUNCTION_NAME = 'locksureSmartHomeProxy';

// Test scenarios
const TEST_SCENARIOS = {
  // Scenario 1: Direct Firebase UID as token (current approach)
  directUid: {
    name: 'Direct Firebase UID as Token',
    description: 'Use Firebase UID directly as access token',
    testUid: '6ue1XtW8cndXJQyHydNo86PW1p43',
    expectedBehavior: 'Should work with direct UID'
  },
  
  // Scenario 2: Amazon User ID mapping
  amazonUidMapping: {
    name: 'Amazon User ID Mapping',
    description: 'Map Amazon user ID to Firebase UID via Firestore',
    testUid: 'amzn1.account.AFWVA2IJ7K4GCTSY6DVJNPVSTW5A',
    expectedBehavior: 'Should map Amazon UID to Firebase UID'
  },
  
  // Scenario 3: Token lookup via Firebase Function
  tokenLookup: {
    name: 'Token Lookup via Firebase Function',
    description: 'Use Firebase function to lookup UID from token',
    testUid: 'Atza|IwEBIC-A4yUkoLd3s-wIYSzk0Du5tRiDylJ1iiu0JffBZZFk0YxbAvtEP9dFhQQcQoP4chjlGSPLI6O5MIlp_YQJIQtKMnGn4Sxs5JawYOu-U4ZEm2AajqPAPitzOaaaKgusorTqpGpijbgFzKCBpseVl-v8Y4PftPRDv7xeNN7BKr0-1NhqjvDjHfJiEpyec4xLhPZvv-XDnAMLjmuFllDMr0ujUdROShXepDw3xo1PX6UCtM8e4DeDcDU0ngwXKYZB3XjXNcfINNkIfiqIGt3JQeBaav-zjxy1AafuXecNA0HC4qgBVtcIaRsyM7LCkzWirftMnmU86L_LGWIrgH-HtXe5suOnmnBhu574xv3glfP3zmHBHqkuAV-qLE825kaR9lPX4J5CNRLBec_tPmdGvM3M',
    expectedBehavior: 'Should lookup UID from Amazon token'
  }
};

// Test results storage
const testResults = {
  scenarios: {},
  summary: {
    total: 0,
    passed: 0,
    failed: 0
  }
};

// Helper function to invoke Lambda
async function invokeLambda(payload) {
  try {
    const command = new InvokeCommand({
      FunctionName: FUNCTION_NAME,
      Payload: JSON.stringify(payload)
    });
    
    const response = await lambda.invoke(command);
    const result = JSON.parse(Buffer.from(response.Payload).toString());
    return { success: true, data: result };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

// Test discovery with different UID approaches
async function testDiscovery(scenario, uid) {
  console.log(`\n🧪 Testing Discovery: ${scenario.name}`);
  console.log(`   UID: ${uid.substring(0, 20)}...`);
  
  const discoveryPayload = {
    directive: {
      header: {
        namespace: 'Alexa.Discovery',
        name: 'Discover',
        payloadVersion: '3',
        messageId: `test-discovery-${Date.now()}`
      },
      payload: {
        scope: {
          type: 'BearerToken',
          token: uid
        }
      }
    }
  };
  
  const result = await invokeLambda(discoveryPayload);
  
  if (!result.success) {
    return { success: false, error: result.error };
  }
  
  // Check if discovery response is valid
  const response = result.data;
  const hasEndpoints = response?.event?.payload?.endpoints?.length > 0;
  const hasFrontRoom = response?.event?.payload?.endpoints?.some(e => e.friendlyName === 'FRONT');
  
  return {
    success: true,
    hasEndpoints,
    hasFrontRoom,
    endpointCount: response?.event?.payload?.endpoints?.length || 0,
    response: response
  };
}

// Test state reporting with different UID approaches
async function testStateReport(scenario, uid) {
  console.log(`\n🔍 Testing State Report: ${scenario.name}`);
  
  const stateReportPayload = {
    directive: {
      header: {
        namespace: 'Alexa.LockController',
        name: 'ReportState',
        payloadVersion: '3',
        messageId: `test-state-${Date.now()}`,
        correlationToken: `test-correlation-${Date.now()}`
      },
      endpoint: {
        scope: {
          type: 'BearerToken',
          token: uid
        },
        endpointId: 'RcW0lotdwT3Eq4fCvuKw'
      },
      payload: {}
    }
  };
  
  const result = await invokeLambda(stateReportPayload);
  
  if (!result.success) {
    return { success: false, error: result.error };
  }
  
  // Check if state report response is valid
  const response = result.data;
  const hasLockState = response?.context?.properties?.some(p => p.namespace === 'Alexa.LockController' && p.name === 'lockState');
  const lockStateValue = response?.context?.properties?.find(p => p.namespace === 'Alexa.LockController' && p.name === 'lockState')?.value;
  
  return {
    success: true,
    hasLockState,
    lockStateValue,
    response: response
  };
}

// Run comprehensive test for a scenario
async function runScenarioTest(scenarioKey, scenario) {
  console.log(`\n🚀 Running Scenario: ${scenario.name}`);
  console.log(`   Description: ${scenario.description}`);
  console.log(`   Expected: ${scenario.expectedBehavior}`);
  
  const results = {
    scenario: scenarioKey,
    name: scenario.name,
    discovery: null,
    stateReport: null,
    overall: false
  };
  
  // Test discovery
  results.discovery = await testDiscovery(scenario, scenario.testUid);
  
  // Test state report
  results.stateReport = await testStateReport(scenario, scenario.testUid);
  
  // Determine overall success
  results.overall = results.discovery.success && 
                   results.discovery.hasEndpoints && 
                   results.discovery.hasFrontRoom &&
                   results.stateReport.success && 
                   results.stateReport.hasLockState;
  
  // Log results
  console.log(`\n📊 Results for ${scenario.name}:`);
  console.log(`   Discovery: ${results.discovery.success ? '✅' : '❌'} ${results.discovery.hasEndpoints ? 'Has endpoints' : 'No endpoints'} ${results.discovery.hasFrontRoom ? 'Has FRONT room' : 'No FRONT room'}`);
  console.log(`   State Report: ${results.stateReport.success ? '✅' : '❌'} ${results.stateReport.hasLockState ? 'Has lock state' : 'No lock state'} (${results.stateReport.lockStateValue || 'N/A'})`);
  console.log(`   Overall: ${results.overall ? '✅ PASS' : '❌ FAIL'}`);
  
  return results;
}

// Main test runner
async function runAllTests() {
  console.log('🧪 Starting Automated UID Testing Framework');
  console.log('============================================');
  
  for (const [scenarioKey, scenario] of Object.entries(TEST_SCENARIOS)) {
    const result = await runScenarioTest(scenarioKey, scenario);
    testResults.scenarios[scenarioKey] = result;
    
    testResults.summary.total++;
    if (result.overall) {
      testResults.summary.passed++;
    } else {
      testResults.summary.failed++;
    }
    
    // Wait between tests
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
  
  // Print summary
  console.log('\n📋 Test Summary');
  console.log('===============');
  console.log(`Total Scenarios: ${testResults.summary.total}`);
  console.log(`Passed: ${testResults.summary.passed} ✅`);
  console.log(`Failed: ${testResults.summary.failed} ❌`);
  console.log(`Success Rate: ${((testResults.summary.passed / testResults.summary.total) * 100).toFixed(1)}%`);
  
  // Find best working scenario
  const workingScenarios = Object.entries(testResults.scenarios)
    .filter(([key, result]) => result.overall)
    .map(([key, result]) => ({ key, name: result.name }));
  
  if (workingScenarios.length > 0) {
    console.log('\n🎉 Working Scenarios:');
    workingScenarios.forEach(scenario => {
      console.log(`   ✅ ${scenario.name} (${scenario.key})`);
    });
  } else {
    console.log('\n❌ No scenarios passed all tests');
  }
  
  // Save results to file
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const filename = `uid-test-results-${timestamp}.json`;
  fs.writeFileSync(filename, JSON.stringify(testResults, null, 2));
  console.log(`\n💾 Results saved to: ${filename}`);
  
  return testResults;
}

// Run the tests
runAllTests().catch(console.error); 