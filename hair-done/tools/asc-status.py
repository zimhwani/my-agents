#!/usr/bin/env python3
"""TestFlight state for Hair Done, straight from the App Store Connect API.

Builds and their state, tester groups, testers and the public link. Reads the
key ID and issuer from the ignored HairDone.xcconfig and signs the JWT with
openssl, so nothing needs installing.
"""
import base64, json, os, re, subprocess, sys, time, urllib.error, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUNDLE = "com.keithchinyanda.hairdone"

def cfg(key):
    text = open(os.path.join(ROOT, "HairDone.xcconfig")).read()
    m = re.search(r"^%s\s*=\s*(\S+)" % key, text, re.M)
    if not m:
        sys.exit("error: %s missing from HairDone.xcconfig" % key)
    return m.group(1)

KEY_ID, ISSUER = cfg("HAIRDONE_ASC_KEY_ID"), cfg("HAIRDONE_ASC_ISSUER_ID")
KEY = os.path.expanduser("~/.appstoreconnect/private_keys/AuthKey_%s.p8" % KEY_ID)

def b64(d): return base64.urlsafe_b64encode(d).rstrip(b"=")

def token():
    head = {"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}
    body = {"iss": ISSUER, "iat": int(time.time()), "exp": int(time.time()) + 600,
            "aud": "appstoreconnect-v1"}
    signing = b64(json.dumps(head, separators=(",", ":")).encode()) + b"." + \
              b64(json.dumps(body, separators=(",", ":")).encode())
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", KEY],
                         input=signing, capture_output=True, check=True).stdout
    i, parts = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F), []
    for _ in range(2):
        n = der[i + 1]
        parts.append(der[i + 2:i + 2 + n].lstrip(b"\0").rjust(32, b"\0"))
        i += 2 + n
    return (signing + b"." + b64(b"".join(parts))).decode()

TOKEN = token()

def get(path):
    req = urllib.request.Request("https://api.appstoreconnect.apple.com" + path,
                                 headers={"Authorization": "Bearer " + TOKEN})
    try:
        return json.load(urllib.request.urlopen(req))
    except urllib.error.HTTPError as e:
        return {"data": None, "error": e.code}

apps = get("/v1/apps?filter[bundleId]=%s" % BUNDLE).get("data") or []
if not apps:
    sys.exit("No app with bundle id %s in App Store Connect yet. Create it: My Apps > + > New App." % BUNDLE)
app = apps[0]["id"]

print("BUILDS")
for b in get("/v1/builds?filter[app]=%s&sort=-uploadedDate&limit=10" % app)["data"]:
    a = b["attributes"]
    sub = (get("/v1/builds/%s/betaAppReviewSubmission" % b["id"]).get("data") or {})
    review = sub.get("attributes", {}).get("betaReviewState", "not submitted")
    print("  %-4s %-8s review=%-19s expired=%-5s uploaded %s" % (
        a["version"], a["processingState"], review, a["expired"], a["uploadedDate"][:10]))

print("\nGROUPS")
for g in get("/v1/betaGroups?filter[app]=%s" % app)["data"]:
    a = g["attributes"]
    builds = [x["attributes"]["version"] for x in get("/v1/betaGroups/%s/builds" % g["id"])["data"]]
    testers = get("/v1/betaGroups/%s/betaTesters?limit=200" % g["id"])["data"]
    print("  %s  [%s]" % (a["name"], "internal" if a["isInternalGroup"] else "external"))
    print("    builds : %s" % (", ".join(builds) or "none"))
    if a.get("publicLink"):
        print("    link   : %s  (enabled=%s)" % (a["publicLink"], a.get("publicLinkEnabled")))
    print("    testers: %d" % len(testers))
    for t in testers:
        ta = t["attributes"]
        name = " ".join(filter(None, [ta.get("firstName"), ta.get("lastName")])) or "(anonymous)"
        print("      %-24s %s" % (name, ta.get("state")))
