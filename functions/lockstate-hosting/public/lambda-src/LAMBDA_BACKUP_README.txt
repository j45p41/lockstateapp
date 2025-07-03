LAMBDA & ALEXA BACKUP RESTORE INSTRUCTIONS
========================================

This directory contains a full backup of your working Alexa Smart Home Lambda integration as of the backup date.

FILES:
------
- lambda-config-backup.json      # Lambda function configuration (env vars, timeout, memory, etc.)
- lambda-policy-backup.json      # Lambda resource policy (permissions/triggers)
- lambda-code-backup.json        # Lambda code S3 location and metadata
- lambda-index-backup.js         # Your current index.js Lambda handler code
- lambda-package-backup.json     # Your current package.json
- lambda-firebase-key-backup.json# Your Firebase service account key

RESTORE STEPS:
--------------
1. Restore Lambda code:
   - Copy lambda-index-backup.js to index.js
   - Copy lambda-package-backup.json to package.json
   - Copy lambda-firebase-key-backup.json to lockstate-e72fc-66f29588f54f.json
   - Reinstall node modules: `npm install`
   - Zip and redeploy to Lambda:
     zip -r lockstate-alexa-skill.zip index.js package.json node_modules/ lockstate-e72fc-66f29588f54f.json
     aws lambda update-function-code --function-name lockstate-alexa-skill --zip-file fileb://lockstate-alexa-skill.zip

2. Restore Lambda configuration:
   - Use the AWS Console or CLI to set environment variables, timeout, and memory as in lambda-config-backup.json
   - Example CLI:
     aws lambda update-function-configuration --function-name lockstate-alexa-skill --timeout <timeout> --memory-size <memory> --environment 'Variables={...}'

3. Restore Lambda permissions:
   - Use the AWS Console or CLI to re-add any resource policies/triggers as in lambda-policy-backup.json
   - Make sure the Alexa Smart Home trigger is present and Skill ID matches.

4. Alexa Developer Console:
   - Ensure the Smart Home endpoint is set to:
     arn:aws:lambda:eu-west-1:487228065075:function:lockstate-alexa-skill
   - Account linking URLs and client ID/secret should match your backup.

5. Test:
   - Re-link the skill in the Alexa app and run device discovery.
   - Confirm all devices and state reporting work as expected.

If you need help restoring, just upload these files and this README in a new chat and ask for a full restore! 