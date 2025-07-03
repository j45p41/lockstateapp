const https = require('https');

// Real access token from the logs
const REAL_ACCESS_TOKEN = 'Atza|IwEBIIaMoQtIPm2nxL08JAnzQgoV4SSmp1QXu8M0hn9KqoiN_Wo9r9epYd6CsUgv5eH8k_bVAuUQPlas7PaHNUQfKBmYY-o5Mt2D-hNqlxgUNdQGxzAGfcEpwDVe-CB6yPrsuVW3c2eNQQbyqKT0GRJ0sOXirOn09C0tqBRmf7TnrpxxryyDTMxEqSDjXReD7CYK5ZlQ7pyIuqVuW15AG5AZkaFdl4JGa7TjbqIQuYOc61kZkcj_VrAKQjfL9s-zkevGMCS71PeTLV6Ix3BloB3G9XayDaBbIMZBdDFEQyGJUHhU-vO1WEioJjH1mM0g3Hl75ceYkpwxLhXc8dJCvdEpSuDDqFSaU7UrCJ08oJ-EU_ItxVWwgw_R5Hrj8kn1u0caOXmLpKAkUttawLONywWQ4V0q';

console.log('🔑 Testing Amazon Profile API with REAL access token...');
console.log('📡 Calling: https://api.amazon.com/user/profile');
console.log('🔐 Token: ' + REAL_ACCESS_TOKEN.substring(0, 50) + '...');

function callAmazonProfileAPI() {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'api.amazon.com',
      port: 443,
      path: '/user/profile',
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${REAL_ACCESS_TOKEN}`,
        'Content-Type': 'application/json'
      }
    };

    const req = https.request(options, (res) => {
      console.log(`📊 Response Status: ${res.statusCode}`);
      console.log(`📋 Response Headers:`, res.headers);

      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        console.log('📄 Raw Response:', data);
        
        try {
          const profile = JSON.parse(data);
          console.log('✅ Parsed Profile:', JSON.stringify(profile, null, 2));
          
          if (profile.user_id) {
            console.log('🎯 SUCCESS! Found Amazon user_id:', profile.user_id);
            console.log('📧 Email:', profile.email || 'N/A');
            console.log('👤 Name:', profile.name || 'N/A');
          } else {
            console.log('❌ No user_id found in response');
          }
          
          resolve(profile);
        } catch (error) {
          console.log('❌ Failed to parse JSON response:', error.message);
          reject(error);
        }
      });
    });

    req.on('error', (error) => {
      console.log('❌ Request failed:', error.message);
      reject(error);
    });

    req.end();
  });
}

// Run the test
callAmazonProfileAPI()
  .then((profile) => {
    console.log('\n🎉 Test completed successfully!');
    console.log('📋 Next step: Use this user_id to query Firestore for the Firebase UID');
  })
  .catch((error) => {
    console.log('\n💥 Test failed:', error.message);
  }); 