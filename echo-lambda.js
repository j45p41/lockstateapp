exports.handler = async function(event, context) {
  console.log('ECHO LAMBDA EVENT:', JSON.stringify(event, null, 2));
  return {
    statusCode: 200,
    body: JSON.stringify({
      received: event
    })
  };
}; 