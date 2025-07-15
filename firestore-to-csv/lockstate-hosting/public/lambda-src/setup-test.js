#!/usr/bin/env node

/**
 * Setup script for Firebase UID Flow Test
 * This script helps configure the test with your actual Lambda URL
 */

import fs from 'fs';
import { execSync } from 'child_process';

console.log('🔧 Setting up Firebase UID Flow Test...\n');

// Get Lambda URL from environment or prompt user
let lambdaUrl = process.env.LAMBDA_URL;

if (!lambdaUrl) {
  console.log('Please provide your Lambda URL:');
  console.log('Format: https://your-api-id.execute-api.region.amazonaws.com/stage');
  console.log('Example: https://abc123.execute-api.us-east-1.amazonaws.com/prod\n');
  
  // Try to get it from AWS CLI if available
  try {
    const apiId = execSync('aws apigateway get-rest-apis --query "items[?name==\'lockstate-hosting\'].id" --output text', { encoding: 'utf8' }).trim();
    const region = execSync('aws configure get region', { encoding: 'utf8' }).trim();
    const stage = 'prod'; // Assuming prod stage
    
    if (apiId && region) {
      lambdaUrl = `https://${apiId}.execute-api.${region}.amazonaws.com/${stage}`;
      console.log(`Found Lambda URL from AWS CLI: ${lambdaUrl}`);
      console.log('Press Enter to use this URL, or type a different one:');
    }
  } catch (error) {
    console.log('Could not auto-detect Lambda URL from AWS CLI');
  }
  
  // For now, we'll use a placeholder that the user needs to update
  lambdaUrl = 'https://your-lambda-url.amazonaws.com';
  console.log(`Using placeholder URL: ${lambdaUrl}`);
  console.log('⚠️  Please update the LAMBDA_URL in test-firebase-uid-flow.js before running the test\n');
}

// Check if Firebase service account file exists
const serviceAccountPath = './lockstate-e72fc-66f29588f54f.json';
if (!fs.existsSync(serviceAccountPath)) {
  console.log('❌ Firebase service account file not found:');
  console.log(`   Expected: ${serviceAccountPath}`);
  console.log('   Please ensure the Firebase service account JSON file is in the current directory\n');
} else {
  console.log('✅ Firebase service account file found');
}

// Check if required packages are installed
const packageJsonPath = './package.json';
if (fs.existsSync(packageJsonPath)) {
  const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
  const requiredDeps = ['node-fetch', 'firebase-admin'];
  const missingDeps = requiredDeps.filter(dep => !packageJson.dependencies?.[dep]);
  
  if (missingDeps.length > 0) {
    console.log('❌ Missing required dependencies:');
    missingDeps.forEach(dep => console.log(`   - ${dep}`));
    console.log('\nRun: npm install node-fetch firebase-admin\n');
  } else {
    console.log('✅ All required dependencies are installed');
  }
} else {
  console.log('❌ package.json not found');
}

// Create a simple test runner script
const testRunner = `#!/usr/bin/env node

// Simple test runner for Firebase UID Flow
import { execSync } from 'child_process';

console.log('🚀 Running Firebase UID Flow Test...\\n');

try {
  // Update the Lambda URL in the test file
  const testFile = './test-firebase-uid-flow.js';
  let testContent = fs.readFileSync(testFile, 'utf8');
  
  // Replace the placeholder URL with the actual URL
  const actualUrl = '${lambdaUrl}';
  testContent = testContent.replace(
    /const LAMBDA_URL = '[^']*'/,
    \`const LAMBDA_URL = '\${actualUrl}'\`
  );
  
  fs.writeFileSync(testFile, testContent);
  console.log('✅ Updated Lambda URL in test file');
  
  // Run the test
  execSync('node test-firebase-uid-flow.js', { stdio: 'inherit' });
  
} catch (error) {
  console.error('❌ Test failed:', error.message);
  process.exit(1);
}
`;

fs.writeFileSync('./run-test.js', testRunner);
console.log('✅ Created test runner: run-test.js');

console.log('\n📋 Setup Complete!');
console.log('\nTo run the test:');
console.log('1. Update the LAMBDA_URL in test-firebase-uid-flow.js with your actual URL');
console.log('2. Run: node run-test.js');
console.log('   or: node test-firebase-uid-flow.js');
console.log('\nThe test will:');
console.log('• Simulate OAuth flow with Firebase UID as state parameter');
console.log('• Test device discovery with the Firebase UID');
console.log('• Test state reporting with the Firebase UID');
console.log('• Test with real users from your Firestore');
console.log('• Generate detailed test results and logs'); 