#!/usr/bin/env node

/**
 * Automated Lambda Testing Script
 * Tests Alexa Smart Home directives locally
 */

import { LambdaClient, InvokeCommand } from '@aws-sdk/client-lambda';

const lambda = new LambdaClient({ region: 'eu-west-1' });
const FUNCTION_NAME = 'locksureSmartHomeProxy';

// Test events
const testEvents = {
  discovery: {
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
          token: '6ue1XtW8cndXJQyHydNo86PW1p43'
        }
      }
    }
  },
  stateReport: {
    directive: {
      header: {
        namespace: 'Alexa.LockController',
        name: 'ReportState',
        payloadVersion: '3',
        messageId: 'test-state-report-' + Date.now(),
        correlationToken: 'test-correlation-token'
      },
      endpoint: {
        endpointId: 'RcW0lotdwT3Eq4fCvuKw',
        scope: {
          type: 'BearerToken',
          token: '6ue1XtW8cndXJQyHydNo86PW1p43'
        }
      },
      payload: {}
    }
  },
  alexaStateReport: {
    directive: {
      header: {
        namespace: 'Alexa',
        name: 'ReportState',
        payloadVersion: '3',
        messageId: 'test-alexa-state-report-' + Date.now(),
        correlationToken: 'test-correlation-token'
      },
      endpoint: {
        endpointId: 'RcW0lotdwT3Eq4fCvuKw',
        scope: {
          type: 'BearerToken',
          token: '6ue1XtW8cndXJQyHydNo86PW1p43'
        }
      },
      payload: {}
    }
  }
};

async function invokeLambda(event, testName) {
  console.log(`\n🧪 Testing: ${testName}`);
  console.log('📤 Sending event:', JSON.stringify(event, null, 2));
  
  try {
    const command = new InvokeCommand({
      FunctionName: FUNCTION_NAME,
      Payload: Buffer.from(JSON.stringify(event)),
      LogType: 'Tail'
    });
    
    const response = await lambda.send(command);
    
    // Parse response
    const payload = JSON.parse(Buffer.from(response.Payload).toString());
    const logs = Buffer.from(response.LogResult, 'base64').toString();
    
    console.log('📥 Response:', JSON.stringify(payload, null, 2));
    console.log('📋 Logs:', logs);
    
    // Validate response
    validateResponse(payload, testName);
    
    return { success: true, payload, logs };
  } catch (error) {
    console.error(`❌ Test failed: ${error.message}`);
    return { success: false, error };
  }
}

function validateResponse(response, testName) {
  console.log(`\n🔍 Validating ${testName} response...`);
  
  switch (testName) {
    case 'Discovery':
      if (response.event?.header?.namespace === 'Alexa.Discovery' && 
          response.event?.header?.name === 'Discover.Response') {
        console.log('✅ Discovery response format is correct');
        
        const endpoints = response.event?.payload?.endpoints;
        if (endpoints && endpoints.length > 0) {
          console.log(`✅ Found ${endpoints.length} endpoint(s)`);
          
          const endpoint = endpoints[0];
          const capabilities = endpoint.capabilities || [];
          const hasLockController = capabilities.some(cap => cap.interface === 'Alexa.LockController');
          const hasPowerController = capabilities.some(cap => cap.interface === 'Alexa.PowerController');
          
          console.log(`✅ LockController capability: ${hasLockController ? '✅' : '❌'}`);
          console.log(`✅ PowerController capability: ${hasPowerController ? '✅' : '❌'}`);
        } else {
          console.log('❌ No endpoints found in discovery response');
        }
      } else {
        console.log('❌ Discovery response format is incorrect');
      }
      break;
      
    case 'State Report':
    case 'Alexa State Report':
      if (response.context?.properties && response.event?.header?.name === 'StateReport') {
        console.log('✅ State report response format is correct');
        
        const properties = response.context.properties;
        const lockState = properties.find(p => p.namespace === 'Alexa.LockController' && p.name === 'lockState');
        const powerState = properties.find(p => p.namespace === 'Alexa.PowerController' && p.name === 'powerState');
        
        console.log(`✅ Lock state: ${lockState ? lockState.value : '❌ Missing'}`);
        console.log(`✅ Power state: ${powerState ? powerState.value : '❌ Missing'}`);
        
        if (lockState && powerState) {
          console.log('✅ Both lock and power states are present');
        } else {
          console.log('❌ Missing required state properties');
        }
      } else {
        console.log('❌ State report response format is incorrect');
      }
      break;
  }
}

async function runAllTests() {
  console.log('🚀 Starting automated Lambda tests...\n');
  
  const results = [];
  
  // Test 1: Discovery
  results.push(await invokeLambda(testEvents.discovery, 'Discovery'));
  
  // Test 2: State Report (LockController namespace)
  results.push(await invokeLambda(testEvents.stateReport, 'State Report'));
  
  // Test 3: State Report (Alexa namespace)
  results.push(await invokeLambda(testEvents.alexaStateReport, 'Alexa State Report'));
  
  // Summary
  console.log('\n📊 Test Summary:');
  const passed = results.filter(r => r.success).length;
  const total = results.length;
  console.log(`✅ Passed: ${passed}/${total}`);
  console.log(`❌ Failed: ${total - passed}/${total}`);
  
  if (passed === total) {
    console.log('\n🎉 All tests passed! Your Lambda is working correctly.');
  } else {
    console.log('\n⚠️  Some tests failed. Check the logs above for details.');
  }
}

// Run tests if this script is executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
  runAllTests().catch(console.error);
}

export { invokeLambda, testEvents, runAllTests }; 