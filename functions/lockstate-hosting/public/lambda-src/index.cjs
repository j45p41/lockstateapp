log('ERROR', 'Lock/Unlock failed', { roomId, error: e.message, stack: e.stack });
      return {
        event: {
          header : { namespace: 'Alexa', name: 'ErrorResponse', payloadVersion: '3',
                     messageId: crypto.randomBytes(16).toString('hex'),
                     correlationToken: header.correlationToken },
    payload: { type: 'NOT_SUPPORTED_IN_CURRENT_MODE', message: 'Sorry, this lock is monitor-only and cannot be unlocked by Alexa. For more info, visit locksure.co.uk/help.' },
    timeOfSample              : new Date().toISOString(),
    uncertaintyInMilliseconds : 500
  }
}; 