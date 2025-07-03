const fetch = require('node-fetch');

const API_BASE = 'https://pi7vzwfxml.execute-api.eu-west-1.amazonaws.com/prod';
const CLIENT_ID = 'amzn1.application-oa2-client.ddbcc3bfaf604d1980b699300a623698';
const REDIRECT_URI = 'https://layla.amazon.com/api/skill/link/1234567890';
const TEST_SECRET = 'test_secret'; // Replace with real secret if needed

function log(step, msg) {
  const ts = new Date().toISOString();
  console.log(`[${ts}] [${step}] ${msg}`);
}

async function main() {
  let state = Math.random().toString(36).substring(2, 15);
  log('Step 1', 'Initiating OAuth request...');
  const params = new URLSearchParams({
    response_type: 'code',
    client_id: CLIENT_ID,
    redirect_uri: REDIRECT_URI,
    state,
    scope: 'profile',
  });
  let authResp;
  try {
    authResp = await fetch(`${API_BASE}/alexaAuth?${params}`, { redirect: 'manual' });
    log('Step 1', `Status: ${authResp.status}`);
    if (authResp.status !== 302) {
      log('Step 1', `FAIL: Expected 302 redirect, got ${authResp.status}`);
      process.exit(1);
    }
    const location = authResp.headers.get('location');
    log('Step 1', `Redirected to: ${location}`);
  } catch (e) {
    log('Step 1', `FAIL: ${e}`);
    process.exit(1);
  }

  log('Step 2', 'Simulating Amazon OAuth approval...');
  const authCode = 'simulated_auth_code_' + Math.random().toString(36).substring(2, 10);
  log('Step 2', `Amazon generated auth code: ${authCode}`);

  log('Step 3', 'Exchanging authorization code for token...');
  const tokenData = new URLSearchParams({
    grant_type: 'authorization_code',
    code: authCode,
    redirect_uri: REDIRECT_URI,
    client_id: CLIENT_ID,
  });
  try {
    const tokenResp = await fetch(`${API_BASE}/alexaToken`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': 'Basic ' + Buffer.from(`${CLIENT_ID}:${TEST_SECRET}`).toString('base64'),
      },
      body: tokenData.toString(),
    });
    log('Step 3', `Status: ${tokenResp.status}`);
    const text = await tokenResp.text();
    log('Step 3', `Response: ${text}`);
    if (tokenResp.status === 200) {
      log('Step 4', 'SUCCESS: Account linked successfully!');
      process.exit(0);
    } else {
      log('Step 4', `FAIL: Token exchange failed with status ${tokenResp.status}`);
      process.exit(2);
    }
  } catch (e) {
    log('Step 3', `FAIL: ${e}`);
    process.exit(1);
  }
}

main(); 