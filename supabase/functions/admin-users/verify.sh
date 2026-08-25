#!/usr/bin/env bash
#
# Integration test for the rank check and the two refusals. pgTAP cannot reach
# an Edge Function, so this is the only test it has -- run it after any edit to
# index.ts.
#
#   npx supabase start
#   npx supabase functions serve admin-users   # in another shell
#   bash supabase/functions/admin-users/verify.sh
#
# The keys below are the fixed demo keys that `supabase start` prints for every
# local stack. They are not secrets and are useless against a real project.
set -u

API=http://127.0.0.1:54321
FN=http://127.0.0.1:54321/functions/v1/admin-users
ANON='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0'
SVC='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU'

mkuser () { # email -> prints user id
  curl -s -X POST "$API/auth/v1/admin/users" \
    -H "apikey: $SVC" -H "Authorization: Bearer $SVC" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"$1\",\"password\":\"correct-horse-battery\",\"email_confirm\":true}" \
    | python -c 'import sys,json; print(json.load(sys.stdin).get("id",""))'
}

token () { # email -> prints access token
  curl -s -X POST "$API/auth/v1/token?grant_type=password" \
    -H "apikey: $ANON" -H 'Content-Type: application/json' \
    -d "{\"email\":\"$1\",\"password\":\"correct-horse-battery\"}" \
    | python -c 'import sys,json; print(json.load(sys.stdin).get("access_token",""))'
}

promote () { # user_id role
  curl -s -X POST "$API/rest/v1/user_roles?on_conflict=user_id" \
    -H "apikey: $SVC" -H "Authorization: Bearer $SVC" \
    -H 'Content-Type: application/json' -H 'Prefer: resolution=merge-duplicates' \
    -d "{\"user_id\":\"$1\",\"role\":\"$2\"}" > /dev/null
}

call () { # token json -> prints "STATUS body"
  curl -s -o /tmp/fnbody -w '%{http_code}' -X POST "$FN" \
    -H "apikey: $ANON" -H "Authorization: Bearer $1" \
    -H 'Content-Type: application/json' -d "$2"
  echo -n ' '
  head -c 400 /tmp/fnbody
  echo
}

pass=0; fail=0
check () { # label expected actual
  if [[ "$3" == "$2"* ]]; then echo "  PASS  $1"; pass=$((pass+1));
  else echo "  FAIL  $1"; echo "        expected: $2"; echo "        actual:   $3"; fail=$((fail+1)); fi
}

echo "=== fixtures ==="
MEMBER_ID=$(mkuser member@fn.test)
BOSS_ID=$(mkuser boss@fn.test)
VICTIM_ID=$(mkuser victim@fn.test)
BOSS2_ID=$(mkuser boss2@fn.test)
echo "member=$MEMBER_ID boss=$BOSS_ID victim=$VICTIM_ID boss2=$BOSS2_ID"
promote "$BOSS_ID" administrator
MEMBER_TOKEN=$(token member@fn.test)
BOSS_TOKEN=$(token boss@fn.test)
[[ -z "$BOSS_TOKEN" ]] && { echo "no admin token; aborting"; exit 1; }

echo
echo "=== the rank check ==="
check "no token is refused"            "401" "$(curl -s -o /dev/null -w '%{http_code}' -X POST "$FN" -H 'Content-Type: application/json' -d '{"action":"list"}')"
check "a member is forbidden"          "403" "$(call "$MEMBER_TOKEN" '{"action":"list"}')"
check "an administrator may list"      "200" "$(call "$BOSS_TOKEN" '{"action":"list"}')"

echo
echo "=== the two refusals ==="
check "cannot change own role"         "400 {\"error\":\"cannot_change_own_role\"}" "$(call "$BOSS_TOKEN" "{\"action\":\"set_role\",\"userId\":\"$BOSS_ID\",\"role\":\"member\"}")"
check "cannot delete self"             "400 {\"error\":\"cannot_delete_self\"}"      "$(call "$BOSS_TOKEN" "{\"action\":\"delete\",\"userId\":\"$BOSS_ID\"}")"

echo
echo "=== role changes between two administrators ==="
# Note: 'last_administrator' is unreachable while 'cannot_change_own_role'
# stands -- if the target is the only administrator, the caller cannot also be
# one. So what is actually testable is that the reachable paths work and that
# lockout is prevented by refusal 1 rather than by refusal 2.
check "promoting a second admin works" "200" "$(call "$BOSS_TOKEN" "{\"action\":\"set_role\",\"userId\":\"$BOSS2_ID\",\"role\":\"administrator\"}")"
BOSS2_TOKEN=$(token boss2@fn.test)
check "either of two admins may demote the other" "200" "$(call "$BOSS2_TOKEN" "{\"action\":\"set_role\",\"userId\":\"$BOSS_ID\",\"role\":\"member\"}")"
check "a demoted admin is immediately forbidden" "403" "$(call "$BOSS_TOKEN" '{"action":"list"}')"
check "the remaining admin still cannot demote itself" "400 {\"error\":\"cannot_change_own_role\"}" "$(call "$BOSS2_TOKEN" "{\"action\":\"set_role\",\"userId\":\"$BOSS2_ID\",\"role\":\"member\"}")"
check "so the project can never be left with no administrator" "400 {\"error\":\"cannot_delete_self\"}" "$(call "$BOSS2_TOKEN" "{\"action\":\"delete\",\"userId\":\"$BOSS2_ID\"}")"

echo
echo "=== ordinary operations ==="
check "delete an ordinary member"      "200" "$(call "$BOSS2_TOKEN" "{\"action\":\"delete\",\"userId\":\"$VICTIM_ID\"}")"
LIST_AFTER=$(call "$BOSS2_TOKEN" '{"action":"list"}')
if echo "$LIST_AFTER" | grep -q 'victim@fn.test'; then
  echo "  FAIL  the deleted account is gone from the list"; fail=$((fail+1))
else
  echo "  PASS  the deleted account is gone from the list"; pass=$((pass+1))
fi
check "unknown action is rejected"     "400 {\"error\":\"unknown_action\"}" "$(call "$BOSS2_TOKEN" '{"action":"do_whatever"}')"

echo
echo "=== audit log ==="
curl -s "$API/rest/v1/admin_audit?select=action,actor_name,target_email,details&order=at.asc" \
  -H "apikey: $SVC" -H "Authorization: Bearer $SVC"
echo
echo "passed=$pass failed=$fail"
exit $(( fail > 0 ))
