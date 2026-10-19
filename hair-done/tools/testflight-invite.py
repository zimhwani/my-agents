#!/usr/bin/env python3
"""Invite someone outside the team to test in TestFlight.

    tools/testflight-invite.py mati.chinyanda@outlook.com Mati Chinyanda

Adds them to the external tester group (made if there isn't one) and says
whether that group already has a build that passed beta review. If it does,
Apple emails them an invite now; if not, run tools/testflight-ship.py with a
build number (no --internal) to submit one, and the invite goes out once
it's approved, usually within a day.
"""
import contextlib, importlib.util, io, json, os, sys, urllib.error, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("status", os.path.join(HERE, "asc-status.py"))
status = importlib.util.module_from_spec(spec)
with contextlib.redirect_stdout(io.StringIO()):
    spec.loader.exec_module(status)

BASE = "https://api.appstoreconnect.apple.com"
if len(sys.argv) < 2 or "@" not in sys.argv[1]:
    sys.exit(__doc__.strip().splitlines()[2].strip())
EMAIL = sys.argv[1].strip()
FIRST = sys.argv[2] if len(sys.argv) > 2 else ""
LAST = " ".join(sys.argv[3:])


def call(method, path, body=None):
    req = urllib.request.Request(BASE + path, method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization": "Bearer " + status.token(), "Content-Type": "application/json"})
    try:
        r = urllib.request.urlopen(req); raw = r.read()
        return r.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


def why(resp):
    return "; ".join(e.get("detail", e.get("title", "")) for e in resp.get("errors", []))


app = status.app
groups = call("GET", "/v1/betaGroups?filter[app]=%s" % app)[1]["data"]
group = next((g for g in groups if not g["attributes"]["isInternalGroup"]), None)
if not group:
    st, resp = call("POST", "/v1/betaGroups", {"data": {"type": "betaGroups", "attributes": {"name": "Testers"},
        "relationships": {"app": {"data": {"type": "apps", "id": app}}}}})
    if st >= 300:
        sys.exit("couldn't make an external group (HTTP %s): %s" % (st, why(resp)))
    group = resp["data"]
    print("made the external group \"Testers\"")
gid, gname = group["id"], group["attributes"]["name"]

attrs = {"email": EMAIL}
if FIRST: attrs["firstName"] = FIRST
if LAST: attrs["lastName"] = LAST
st, resp = call("POST", "/v1/betaTesters", {"data": {"type": "betaTesters", "attributes": attrs,
    "relationships": {"betaGroups": {"data": [{"type": "betaGroups", "id": gid}]}}}})
if st < 300:
    print("%s added to \"%s\"" % (EMAIL, gname))
else:
    # Already a tester somewhere: put them in this group too.
    found = call("GET", "/v1/betaTesters?filter[email]=%s&filter[apps]=%s" % (EMAIL, app))[1].get("data") or []
    if not found:
        sys.exit("couldn't add %s (HTTP %s): %s" % (EMAIL, st, why(resp)))
    st2, resp2 = call("POST", "/v1/betaGroups/%s/relationships/betaTesters" % gid,
                      {"data": [{"type": "betaTesters", "id": found[0]["id"]}]})
    if st2 >= 300:
        sys.exit("couldn't add %s to \"%s\" (HTTP %s): %s" % (EMAIL, gname, st2, why(resp2)))
    print("%s was already a tester; now in \"%s\" too" % (EMAIL, gname))

builds = call("GET", "/v1/betaGroups/%s/builds?limit=20" % gid)[1].get("data") or []
approved = []
for b in builds:
    detail = call("GET", "/v1/builds/%s/buildBetaDetail" % b["id"])[1].get("data") or {}
    if detail.get("attributes", {}).get("externalBuildState") in ("READY_FOR_BETA_TESTING", "IN_BETA_TESTING"):
        approved.append(b["attributes"]["version"])
if approved:
    print("build %s is approved for this group, so Apple emails %s an invite now." % (max(approved, key=int), EMAIL))
    print("They install TestFlight from the App Store, open the email on their iPhone, and tap View in TestFlight.")
else:
    print("no build in \"%s\" has passed beta review yet, so no invite has gone out." % gname)
    print("Send one for review:  tools/testflight-ship.py <build number>   (no --internal)")
    print("Apple reviews it, usually within a day, then emails %s the invite." % EMAIL)
