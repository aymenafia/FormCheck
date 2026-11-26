#!/usr/bin/env python3
"""Attach the newest valid build (version 1.1.1) to the App Store version and submit for review."""
import json, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from asc import call
APP = "6790111242"
VER = json.loads((pathlib.Path(__file__).parent.parent / "AppStore/asc_ids.json").read_text())["version_111"]
builds = call("GET", f"/v1/builds?filter[app]={APP}&filter[processingState]=VALID&filter[preReleaseVersion.version]=1.1.1&sort=-uploadedDate")["data"]
if not builds: sys.exit("no valid 1.1.1 build yet")
b = builds[0]["id"]; print("build", builds[0]["attributes"]["version"])
call("PATCH", f"/v1/builds/{b}", {"data": {"type": "builds", "id": b, "attributes": {"usesNonExemptEncryption": False}}})
call("PATCH", f"/v1/appStoreVersions/{VER}/relationships/build", {"data": {"type": "builds", "id": b}}); print("build attached")
sub = call("POST", "/v1/reviewSubmissions", {"data": {"type": "reviewSubmissions", "attributes": {"platform": "IOS"}, "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})
if "data" not in sub:
    sub = {"data": call("GET", f"/v1/reviewSubmissions?filter[app]={APP}&filter[state]=READY_FOR_REVIEW")["data"][0]}
sid = sub["data"]["id"]
r = call("POST", "/v1/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems", "relationships": {
    "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sid}}, "appStoreVersion": {"data": {"type": "appStoreVersions", "id": VER}}}}})
print("version added", "ok" if "data" in r else "see error")
r = call("PATCH", f"/v1/reviewSubmissions/{sid}", {"data": {"type": "reviewSubmissions", "id": sid, "attributes": {"submitted": True}}})
print("SUBMITTED" if "data" in r else "submit failed", r.get("data", {}).get("attributes", {}).get("state"))
