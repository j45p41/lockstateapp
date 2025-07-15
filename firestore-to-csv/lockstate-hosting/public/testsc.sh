#!/usr/bin/env bash
set -euo pipefail

# ─── CONFIG ────────────────────────────────────────────────────────────────
API_ROOT="https://18glpgnilb.execute-api.eu-west-1.amazonaws.com/prod"
REDIRECT_URI="https://layla.amazon.com/api/skill/link/amzn1.ask.skill.89751fb9-1b7f-4c40-8c9f-a5231bdb3998"
UID="6ue1XtW8cndXJQyHydNo86PW1p43"       # ← your real Firebase UID
EMAIL="new2@maintest.com"               # ← your real Firebase email
PASS="test123"                          # ← that account’s exact password

echo
echo "1) GET  /alexaAuth?uid=… → fetch 'state' from the 302 Location"
STATE=$(
  curl -s -D - -o /dev/null -G \
    --data-urlencode "uid=${UID}" \
    --data-urlencode "redirect_uri=${REDIRECT_URI}" \
    "${API_ROOT}/alexaAuth" \
  | tr -d $'\r' \
  | awk -F'state=' '/^location:/ {print $2}'
)
echo "   → STATE=${STATE}"
[[ -n "$STATE" ]] || { echo "✖️  Failed to extract STATE"; exit 1; }

echo
echo "2) GET  /alexaCallback?code=poke&state=… → fetch our AUTH_CODE from the 302"
AUTH_CODE=$(
  curl -s -D - -o /dev/null -G \
    --data-urlencode "code=poke" \
    --data-urlencode "state=${STATE}" \
    "${API_ROOT}/alexaCallback" \
  | tr -d $'\r' \
  | awk -F'code=' '/^location:/ {print $2}'
)
echo "   → AUTH_CODE=${AUTH_CODE}"
[[ -n "$AUTH_CODE" ]] || { echo "✖️  Failed to extract AUTH_CODE"; exit 1; }

echo
echo "3) POST /alexaToken       → swap AUTH_CODE for access_token"
curl -i -X POST "${API_ROOT}/alexaToken" \
     -H 'Content-Type: application/x-www-form-urlencoded' \
     --data-urlencode "grant_type=authorization_code" \
     --data-urlencode "code=${AUTH_CODE}" \
     --data-urlencode "state=${STATE}" \
| head -n 10

echo
echo "✅ Done. If you see HTTP/2 200 and JSON {\"access_token\":\"${UID}\",…} the linking flow works."
