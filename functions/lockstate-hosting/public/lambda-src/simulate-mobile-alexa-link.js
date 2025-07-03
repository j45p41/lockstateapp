(async () => {
  const fetch = (await import('node-fetch')).default;

  const API_BASE = 'https://0dpfo4tmbd.execute-api.eu-west-1.amazonaws.com/prod';
  const CLIENT_ID = 'amzn1.application-oa2-client.ddbcc3bfaf604d1980b699300a623698';
  const REDIRECT_URI = 'https://layla.amazon.com/api/skill/link/M2KB1TY529INC9';
  const TEST_SECRET = 'amzn1.oa2-cs.v1.6b02e945a9e3e041a43abdb405a1e76f80081db17080e5cca01962b90e21f815'; // Real Alexa client secret
  const authCode = 'ANodmYwreTcmiJAdYCPe';

  function log(step, msg) {
    const ts = new Date().toISOString();
    console.log(`[${ts}] [${step}] ${msg}`);
  }

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
  log('Step 2', `Using real Amazon auth code: ${authCode}`);

  log('Step 3', 'Exchanging authorization code for token...');
  const tokenData = new URLSearchParams({
    grant_type: 'authorization_code',
    code: authCode,
    redirect_uri: REDIRECT_URI,
    client_id: CLIENT_ID,
  });
  const tokenResp = await fetch(`${API_BASE}/alexaToken`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Authorization': 'Basic ' + Buffer.from(`${CLIENT_ID}:${TEST_SECRET}`).toString('base64'),
    },
    body: tokenData.toString(),
  });
  log('Step 3', `Status: ${tokenResp.status}`);
  const tokenText = await tokenResp.text();
  log('Step 3', `Response: ${tokenText}`);
  if (tokenResp.status === 200) {
    log('Step 4', 'SUCCESS: Token exchange succeeded!');
    process.exit(0);
  } else {
    log('Step 4', `FAIL: Token exchange failed with status ${tokenResp.status}`);
    process.exit(2);
  }
})(); 