const functions = require('firebase-functions');
const admin     = require('firebase-admin');
const https      = require('https');

if (!admin.apps.length) admin.initializeApp();

const { ALEXA_CLIENT_ID, ALEXA_CLIENT_SECRET } = process.env;
const SENSOR_MODE = process.env.SENSOR_MODE === 'contact';

function log(lvl,msg,data={}){ console.log(JSON.stringify({ts:new Date().toISOString(),lvl,msg,data})); }

function fetchToken(refreshToken){
  return new Promise((resolve,reject)=>{
    const body = new URLSearchParams({
      grant_type:'refresh_token',
      refresh_token:refreshToken,
      client_id:ALEXA_CLIENT_ID,
      client_secret:ALEXA_CLIENT_SECRET
    }).toString();
    const req = https.request({hostname:'api.amazon.com',path:'/auth/o2/token',method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded','Content-Length':Buffer.byteLength(body)}},res=>{
      let data='';res.on('data',d=>data+=d);res.on('end',()=>{
        try{const j=JSON.parse(data);resolve(j);}catch(e){reject(e);} });});
    req.on('error',reject);req.write(body);req.end();
  });
}

function postChangeReport(accessToken,payload){
  return new Promise((resolve,reject)=>{
    const body = JSON.stringify(payload);
    const req = https.request({hostname:'api.amazonalexa.com',path:'/v3/events',method:'POST',headers:{'Content-Type':'application/json','Authorization':`Bearer ${accessToken}`,'Content-Length':Buffer.byteLength(body)}},res=>{
      let data='';res.on('data',d=>data+=d);res.on('end',()=>resolve({status:res.statusCode,body:data}));});
    req.on('error',reject);req.write(body);req.end();
  });
}

function stateToLock(state){ return (state===1||state===3)?'LOCKED':'UNLOCKED'; }
function stateToDetection(state){ return (state===1||state===3)?'DETECTED':'NOT_DETECTED'; }

exports.alexaChangeReport = functions.firestore.document('rooms/{roomId}').onUpdate(async (change,context)=>{
  const before = change.before.data();
  const after  = change.after.data();
  if (before.state === after.state) return null;

  const uid     = after.userId;
  const refresh = (await admin.firestore().collection('users').doc(uid).get()).get('alexaRefreshToken');
  if (!refresh) { log('WARN','No refresh token for user',{uid}); return null; }

  try{
    const tokRes = await fetchToken(refresh);
    const access = tokRes.access_token;
    const prop = SENSOR_MODE ? {
        namespace:'Alexa.ContactSensor',
        name:'detectionState',
        value:stateToDetection(after.state),
        timeOfSample:new Date().toISOString(),
        uncertaintyInMilliseconds:500
      } : {
        namespace:'Alexa.LockController',
        name:'lockState',
        value:stateToLock(after.state),
        timeOfSample:new Date().toISOString(),
        uncertaintyInMilliseconds:500
      };

    const eventPayload = {
      context:{
        properties:[ prop, {
          namespace:'Alexa.EndpointHealth',
          name:'connectivity',
          value:{value:'OK'},
          timeOfSample:new Date().toISOString(),
          uncertaintyInMilliseconds:500
        }]
      },
      event:{
        header:{
          namespace:'Alexa',
          name:'ChangeReport',
          payloadVersion:'3',
          messageId:context.eventId || require('crypto').randomBytes(16).toString('hex')
        },
        endpoint:{
          scope:{type:'BearerToken',token:uid},
          endpointId:after.roomId || context.params.roomId
        },
        payload:{
          change:{
            cause:{type:'PHYSICAL_INTERACTION'},
            properties:[ prop ]
          }
        }
      }
    };
    const resp = await postChangeReport(access,eventPayload);
    log('INFO','ChangeReport post',resp);
  }catch(e){ log('ERROR','ChangeReport failed',{msg:e.message,stack:e.stack}); }

  return null;
}); 