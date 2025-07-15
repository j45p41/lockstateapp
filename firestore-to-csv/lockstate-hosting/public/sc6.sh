export AWS_PAGER=""

# re-deploy account-linking routes
./sc5.sh

# wait ~30s for the prod stage to refresh, then re-run your smoke tests:
STATE=$(
  curl -s -D - -o /dev/null -G \
    --data-urlencode "uid=6ue1XtW8cndXJQyHydNo86PW1p43" \
    --data-urlencode "redirect_uri=https://layla.amazon.com/api/skill/link/amzn1.ask.skill.89751fb9-1b7f-4c40-8c9f-a5231bdb3998" \
    https://ayb2a2m447.execute-api.eu-west-1.amazonaws.com/prod/alexaAuth \
  | awk -F'state=' '/^location:/ {print $2}'
)

echo "STATE=$STATE"   # should be non-empty

AUTH_CODE=$(
  curl -s -D - -o /dev/null -G \
    --data-urlencode "code=poke" \
    --data-urlencode "state=$STATE" \
    https://ayb2a2m447.execute-api.eu-west-1.amazonaws.com/prod/alexaCallback \
  | awk -F'code=' '/^location:/ {print $2}'
)

echo "AUTH_CODE=$AUTH_CODE"  # should be non-empty

curl -i -X POST https://ayb2a2m447.execute-api.eu-west-1.amazonaws.com/prod/alexaToken \
     -H 'Content-Type: application/x-www-form-urlencoded' \
     --data-urlencode "grant_type=authorization_code" \
     --data-urlencode "code=$AUTH_CODE" \
     --data-urlencode "state=$STATE"
