#!/usr/bin/env python
"""Delete songbook-test-admin@songbook.test from the live project.

The account is a full administrator and its password is in an old session
transcript, so it has to go. Deleting rather than rotating: a future admin-panel
browser walk can make a fresh one, and a standing full-power account in
production is the thing that caused this in the first place.

The secret key is read from the linked Supabase CLI and held in memory only. It
is never printed, never written to disk, and never passed on a command line.

    python tools/delete-test-admin.py            # show what would be deleted
    python tools/delete-test-admin.py --delete   # actually delete it

Requires `npx supabase login` and the project linked (both already true here).
"""
import json
import subprocess
import sys
import urllib.error
import urllib.request

PROJECT_REF = "sjsgrxvebzsuubebbfwx"
API = "https://%s.supabase.co" % PROJECT_REF
TARGET = "songbook-test-admin@songbook.test"


def secret_key():
    """The service_role / secret key for the linked project, from the CLI."""
    out = subprocess.run(
        ["npx", "supabase", "projects", "api-keys",
         "--project-ref", PROJECT_REF, "--output", "json"],
        capture_output=True, text=True, shell=(sys.platform == "win32"),
    )
    if out.returncode != 0:
        sys.exit("supabase projects api-keys failed:\n" + out.stderr.strip())
    try:
        rows = json.loads(out.stdout)
    except ValueError:
        sys.exit("could not parse the CLI's JSON output")
    if isinstance(rows, dict):
        rows = [rows]
    for row in rows:
        name = str(row.get("name", "")).lower()
        if "service" in name or name == "secret":
            for field in ("api_key", "apiKey", "secret", "value"):
                if row.get(field):
                    return row[field]
    sys.exit("no service_role/secret key in: %s"
             % [r.get("name") for r in rows])


def call(method, path, key):
    request = urllib.request.Request(API + path, method=method)
    request.add_header("apikey", key)
    request.add_header("Authorization", "Bearer " + key)
    request.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            body = response.read().decode("utf-8")
            return response.status, (json.loads(body) if body.strip() else {})
    except urllib.error.HTTPError as error:
        # Never echo the response verbatim -- it can carry the request headers.
        sys.exit("%s %s -> HTTP %d" % (method, path, error.code))


def main():
    delete = "--delete" in sys.argv
    key = secret_key()

    status, page = call("GET", "/auth/v1/admin/users?page=1&per_page=200", key)
    users = page.get("users", [])
    print("%d accounts in the project" % len(users))

    match = [u for u in users if u.get("email", "").lower() == TARGET]
    if not match:
        print("%s is not there -- nothing to do." % TARGET)
        return
    user = match[0]
    print("found %s  id=%s  created=%s  last_sign_in=%s"
          % (TARGET, user["id"], user.get("created_at"),
             user.get("last_sign_in_at") or "never"))

    if not delete:
        print("\nDry run. Re-run with --delete to remove it.")
        return

    call("DELETE", "/auth/v1/admin/users/%s" % user["id"], key)
    print("deleted.")

    # Prove it, rather than trusting the 200.
    _, page = call("GET", "/auth/v1/admin/users?page=1&per_page=200", key)
    still = [u for u in page.get("users", [])
             if u.get("email", "").lower() == TARGET]
    print("verified: %s" % ("STILL PRESENT -- check the dashboard" if still
                            else "gone, %d accounts remain"
                            % len(page.get("users", []))))


if __name__ == "__main__":
    main()
