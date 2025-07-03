#!/bin/bash

# Real access token from the logs
REAL_ACCESS_TOKEN="Atza|IwEBIIaMoQtIPm2nxL08JAnzQgoV4SSmp1QXu8M0hn9KqoiN_Wo9r9epYd6CsUgv5eH8k_bVAuUQPlas7PaHNUQfKBmYY-o5Mt2D-hNqlxgUNdQGxzAGfcEpwDVe-CB6yPrsuVW3c2eNQQbyqKT0GRJ0sOXirOn09C0tqBRmf7TnrpxxryyDTMxEqSDjXReD7CYK5ZlQ7pyIuqVuW15AG5AZkaFdl4JGa7TjbqIQuYOc61kZkcj_VrAKQjfL9s-zkevGMCS71PeTLV6Ix3BloB3G9XayDaBbIMZBdDFEQyGJUHhU-vO1WEioJjH1mM0g3Hl75ceYkpwxLhXc8dJCvdEpSuDDqFSaU7UrCJ08oJ-EU_ItxVWwgw_R5Hrj8kn1u0caOXmLpKAkUttawLONywWQ4V0q"

echo "🔑 Testing Amazon Profile API with REAL access token..."
echo "📡 Calling: https://api.amazon.com/user/profile"
echo "🔐 Token: ${REAL_ACCESS_TOKEN:0:50}..."

# Make the API call
echo "📊 Making request..."
curl -s -H "Authorization: Bearer $REAL_ACCESS_TOKEN" \
     -H "Content-Type: application/json" \
     https://api.amazon.com/user/profile

echo ""
echo "🎉 Request completed!" 