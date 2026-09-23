#!/usr/bin/env python3
"""Put an uploaded build in front of testers.

    tools/testflight-ship.py --internal        newest uploaded build, internal testers (no review)
    tools/testflight-ship.py 21 --internal     a specific build number
    tools/testflight-ship.py 21                external group: submits for beta review

Waits for Apple to finish processing, adds the build to the group, and (for
external testers) submits it for beta review and watches until it settles.
"""
import contextlib, importlib.util, io, json, os, sys, time, urllib.error, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("status", os.path.join(HERE, "asc-status.py"))
status = importlib.util.module_from_spec(spec)
with contextlib.redirect_stdout(io.StringIO()):
    spec.loader.exec_module(status)

BASE = "https://api.appstoreconnect.apple.com"
args = [a for a in sys.argv[1:] if not a.startswith("--")]
INTERNAL = "--internal" in sys.argv
VERSION = args[0] if args else None


def call(method, path, body=None):
    req = urllib.request.Request(BASE + path, method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization": "Bearer " + status.token(), "Content-Type": "application/json"})
    try:
        r = urllib.request.urlopen(req); raw = r.read()
        return r.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


def say(msg):
    print("build %s: %s" % (VERSION, msg), flush=True)


app = status.app
if VERSION is None:
    newest = call("GET", "/v1/builds?filter[app]=%s&sort=-uploadedDate&limit=1" % app)[1].get("data") or []
    if not newest:
        sys.exit("no builds uploaded yet")
    VERSION = newest[0]["attributes"]["version"]
    print("newest upload is build %s" % VERSION, flush=True)
else:
    known = [b["attributes"]["version"] for b in (call("GET", "/v1/builds?filter[app]=%s&sort=-uploadedDate&limit=10" % app)[1].get("data") or [])]
    if known and VERSION not in known:
        sys.exit("no build %s in App Store Connect. Recent uploads: %s. The number is the commit count; check release.sh's first line." % (VERSION, ", ".join(known)))
groups = call("GET", "/v1/betaGroups?filter[app]=%s" % app)[1]["data"]
group = next((g["id"] for g in groups if g["attributes"]["isInternalGroup"] == INTERNAL), None)
if not group:
    sys.exit("no %s tester group exists; make one in App Store Connect > TestFlight" % ("internal" if INTERNAL else "external"))

build, deadline = None, time.time() + 45 * 60
while time.time() < deadline:
    found = call("GET", "/v1/builds?filter[app]=%s&filter[version]=%s" % (app, VERSION))[1].get("data") or []
    if found and found[0]["attributes"]["processingState"] in ("VALID", "FAILED", "INVALID"):
        build = found[0]; break
    say("still processing"); time.sleep(60)
if not build:
    say("still processing after 45 min"); sys.exit(1)
if build["attributes"]["processingState"] != "VALID":
    say("processing %s" % build["attributes"]["processingState"]); sys.exit(1)

st, _ = call("POST", "/v1/betaGroups/%s/relationships/builds" % group,
             {"data": [{"type": "builds", "id": build["id"]}]})
in_group = any(b["id"] == build["id"] for b in call("GET", "/v1/betaGroups/%s/builds" % group)[1].get("data") or [])
label = "internal" if INTERNAL else "external"
if st < 300:
    say("processed; added to the %s group" % label)
elif in_group:
    say("processed; already in the %s group (automatic distribution)" % label)
else:
    say("processed, but couldn't add it to the %s group (HTTP %s). Add it in App Store Connect > TestFlight." % (label, st))

if INTERNAL:
    say("internal testers get it now; no review needed")
    sys.exit(0)

st, resp = call("POST", "/v1/betaAppReviewSubmissions",
    {"data": {"type": "betaAppReviewSubmissions",
              "relationships": {"build": {"data": {"type": "builds", "id": build["id"]}}}}})
if st < 300:
    say("submitted for beta review")
else:
    say("submission refused (HTTP %s): %s" % (st, "; ".join(e.get("detail", "") for e in resp.get("errors", []))))

state = None
for _ in range(20):
    time.sleep(90)
    sub = call("GET", "/v1/builds/%s/betaAppReviewSubmission" % build["id"])[1].get("data")
    state = (sub or {}).get("attributes", {}).get("betaReviewState")
    if state in ("APPROVED", "REJECTED"):
        say("review %s" % state); sys.exit(0 if state == "APPROVED" else 1)
say("review still %s after 30 min" % state)
