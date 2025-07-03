const admin = require('firebase-admin');
const fs = require('fs');
const { Parser } = require('json2csv');

// Initialize Firestore using your service account key
const serviceAccount = require('./serviceAccount.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});
const db = admin.firestore();

// Collection names
const notificationsCollection = 'notifications';
const usersCollection = 'users';

// Helper function to parse the received_at field.
// If the value is a 14-digit string (YYYYMMDDHHMMSS), convert it to a valid Date.
function parseReceivedAt(value) {
  const str = value.toString();
  const regex = /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/;
  const match = str.match(regex);
  if (match) {
    const isoStr = `${match[1]}-${match[2]}-${match[3]}T${match[4]}:${match[5]}:${match[6]}`;
    return new Date(isoStr);
  }
  // Handle Unix timestamp in milliseconds (13+ digits)
  if (/^\d{13,}$/.test(str)) {
    return new Date(Number(str));
  }
  return new Date(value);
}

// Helper function to format a time difference in seconds into an extended breakdown.
// Using approximate conversions: 1 year=365 days, 1 month=30 days.
function formatTimeExtended(seconds) {
  let remaining = seconds;
  const years = Math.floor(remaining / (365 * 24 * 3600));
  remaining %= (365 * 24 * 3600);
  const months = Math.floor(remaining / (30 * 24 * 3600));
  remaining %= (30 * 24 * 3600);
  const days = Math.floor(remaining / (24 * 3600));
  remaining %= (24 * 3600);
  const hours = Math.floor(remaining / 3600);
  remaining %= 3600;
  const minutes = Math.floor(remaining / 60);
  const secs = Math.floor(remaining % 60);
  
  const parts = [];
  if (years > 0) parts.push(`${years}y`);
  if (months > 0) parts.push(`${months}mo`);
  if (days > 0) parts.push(`${days}d`);
  parts.push(`${hours}h`, `${minutes}m`, `${secs}s`);
  return parts.join(' ');
}

// Retrieve all users' email addresses from the "users" collection.
// Assumes that each document's ID is the userId and contains an "email" field.
async function getAllUserEmails() {
  const snapshot = await db.collection(usersCollection).get();
  const emailMapping = {};
  snapshot.forEach(doc => {
    const data = doc.data();
    emailMapping[doc.id] = data.email || '';
  });
  return emailMapping;
}

// Process notifications for a single user.
// Returns an array of event records for that user.
async function processUser(userId) {
  // Force Firestore to fetch data from the server
  const snapshot = await db.collection(notificationsCollection)
    .where('userId', '==', userId)
    .orderBy('received_at')
    .get({ source: 'server' }); // Fetch from server to ensure latest data

  const events = [];
  const lastStateByDeviceName = {};

  snapshot.docs.forEach(doc => {
    const docData = doc.data();
    if (!docData.received_at) return; // Skip if no timestamp

    let dateObj;
    if (docData.received_at && typeof docData.received_at.toDate === 'function') {
      dateObj = docData.received_at.toDate();
    } else {
      dateObj = parseReceivedAt(docData.received_at);
    }
    if (isNaN(dateObj.getTime())) {
      console.error(`Skipping document ${doc.id} due to invalid date: ${docData.received_at}`);
      return;
    }

    // Build a record for this event.
    const record = {
      userId,
      deviceName: docData.deviceName,
      date: dateObj.toISOString().split('T')[0],             // YYYY-MM-DD
      time: dateObj.toISOString().split('T')[1].substring(0,8), // HH:MM:SS
      state: docData.state,
      volts: docData.volts,
      radioPowerLevel: docData.radioPowerLevel,
      repeated: '',
      ts: dateObj.getTime()
    };

    // Mark as "X" if the previous event for this deviceName had the same state.
    if (lastStateByDeviceName[docData.deviceName] !== undefined &&
        lastStateByDeviceName[docData.deviceName] === docData.state) {
      record.repeated = 'X';
    }
    lastStateByDeviceName[docData.deviceName] = docData.state;

    events.push(record);
  });
  return events;
}

// Main function: process all available users and generate users.csv and stats.csv.
async function main() {
  // Retrieve all users' email mapping from the "users" collection.
  const emailMapping = await getAllUserEmails();
  const userIds = Object.keys(emailMapping);
  
  let allEvents = [];
  // Process each user.
  for (const userId of userIds) {
    const userEvents = await processUser(userId);
    // Add the email field for each event.
    userEvents.forEach(event => {
      event.email = emailMapping[userId] || '';
    });
    allEvents = allEvents.concat(userEvents);
  }
  
  // Group events by userId and deviceName for adjusting repeated flags and computing stats.
  const groups = {}; // key: `${userId}_${deviceName}`
  allEvents.forEach(event => {
    const key = `${event.userId}_${event.deviceName}`;
    if (!groups[key]) {
      groups[key] = [];
    }
    groups[key].push(event);
  });
  
  // For each group, sort events by timestamp, update repeated flags, and compute statistics.
  const stats = [];
  Object.keys(groups).forEach(key => {
    const events = groups[key];
    events.sort((a, b) => a.ts - b.ts);
    // Update repeated flag: if an event marked "X" is followed by an event within 30 seconds, mark it "XOK".
    for (let i = 0; i < events.length - 1; i++) {
      if (events[i].repeated === 'X') {
        const diff = events[i+1].ts - events[i].ts;
        if (diff < 30000) { // less than 30 seconds
          events[i].repeated = 'XOK';
        }
      }
    }
    // Compute statistics for this group.
    const totalEvents = events.length;
    const first = events[0];
    const last = events[events.length - 1];
    // Decline in volts from first to last event.
    const voltsDecline = (first.volts || 0) - (last.volts || 0);
    // Time elapsed in seconds.
    const timeElapsedSec = (last.ts - first.ts) / 1000;
    const formattedTimeElapsed = formatTimeExtended(timeElapsedSec);
    // Voltage decay rate multiplied by 10,000.
    const voltageDecayRate = timeElapsedSec > 0 ? (voltsDecline / timeElapsedSec) * 10000 : 0;
    const XCount = events.filter(e => e.repeated === 'X').length;
    const XOKCount = events.filter(e => e.repeated === 'XOK').length;
    
    stats.push({
      email: first.email,
      deviceName: first.deviceName,
      totalEvents,
      voltsDecline,
      timeElapsed: formattedTimeElapsed,
      voltageDecayRate,
      XCount,
      XOKCount,
      firstKnownEvent: new Date(first.ts).toISOString(),
      lastKnownEvent: new Date(last.ts).toISOString()
    });
  });
  
  // Write users.csv – one row per event.
  // Remove the helper "ts" field.
  const usersData = allEvents.map(e => ({
    userId: e.userId,
    email: e.email,
    deviceName: e.deviceName,
    date: e.date,
    time: e.time,
    state: e.state,
    volts: e.volts,
    radioPowerLevel: e.radioPowerLevel,
    repeated: e.repeated
  }));
  
  const usersCsvParser = new Parser({ 
    fields: ['userId', 'email', 'deviceName', 'date', 'time', 'state', 'volts', 'radioPowerLevel', 'repeated'] 
  });
  const usersCsv = usersCsvParser.parse(usersData);
  fs.writeFileSync('users.csv', usersCsv);
  
  // Write stats.csv – aggregated statistics per user & deviceName.
  // The userId column is removed.
  const statsCsvParser = new Parser({ 
    fields: [
      'email',
      'deviceName',
      'totalEvents',
      'voltsDecline',
      'timeElapsed',
      'voltageDecayRate',
      'XCount',
      'XOKCount',
      'firstKnownEvent',
      'lastKnownEvent'
    ]
  });
  const statsCsv = statsCsvParser.parse(stats);
  fs.writeFileSync('stats.csv', statsCsv);
  
  console.log('CSV files generated: users.csv and stats.csv');
}

main().catch(console.error);
