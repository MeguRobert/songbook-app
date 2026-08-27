#!/usr/bin/env bash
#
# Asks the instrumentation question at the moment of the edit.
#
# CLAUDE.md states the rule; this is what makes it land. A rule in a file that is
# read once at session start loses to two hours of momentum on a refactor, and
# the change that most needs a diagnostic event is exactly the change nobody was
# thinking about diagnostics during.
#
# It never blocks and never fails an edit. It injects three lines of context and
# exits 0, including when jq is missing, the payload is unexpected, or the path
# is not one it cares about. A hook that can break editing is worse than no hook.
#
# Wired from .claude/settings.json as a PostToolUse hook on Write|Edit.

set -u

payload="$(cat 2>/dev/null || true)"
[ -z "$payload" ] && exit 0

command -v jq >/dev/null 2>&1 || exit 0

file="$(printf '%s' "$payload" \
  | jq -r '.tool_input.file_path // .tool_response.filePath // empty' 2>/dev/null)"
[ -z "$file" ] && exit 0

# Tests are where instrumentation is asserted, not where it is added. Asking
# there would fire on the very files written in answer to the question.
case "$file" in
  */test/*|*/tests/*|*_test.dart|*_test.sql|*test_*.py) exit 0 ;;
esac

# The three trees where a change can go unrecorded. Everything else — docs,
# tooling, assets, the harnesses in songbook_app/tool/ — is out of scope, and
# firing there is how a reminder becomes noise that gets switched off.
case "$file" in
  *songbook_app/lib/*|*supabase/functions/*|*supabase/migrations/*) ;;
  *) exit 0 ;;
esac

jq -n --arg file "$file" '{
  suppressOutput: true,
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: (
      "Instrumentation check for \($file) — see CLAUDE.md.\n" +
      "1. Did this add or change a handled failure, a degraded result, or a silent fallback? " +
      "It needs an error_reports row via ThrottledCrashReporter.note(DiagnosticEvent...). " +
      "A new event value lands with its writer, in the same commit as the migration that " +
      "extends the check constraint.\n" +
      "2. Did this add or change a privileged action — a role, an account, the shared " +
      "settings, a moderation decision? It needs an admin_audit row, written server-side " +
      "by a security-definer trigger or the admin-users function. Never from the client.\n" +
      "details and audit rows hold measurements only: never lyrics, images, file names, " +
      "addresses, or text a user typed. If neither applies, say so in one line and move on."
    )
  }
}'
