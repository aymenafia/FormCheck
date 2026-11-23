#!/usr/bin/env python3
"""Tiny App Store Connect API client. Usage: asc.py GET /v1/apps  |  asc.py POST /v1/x '{json}'"""
import jwt, time, sys, json, requests, os, pathlib
KEY_ID=os.environ.get("ASC_KEY_ID","57QJYDWS33"); ISSUER=os.environ.get("ASC_ISSUER","83fd3fd9-1ee3-495d-b062-61d0d0d5aa40")
KEY=pathlib.Path(os.environ.get("ASC_KEY_PATH",os.path.expanduser(f"~/Downloads/Dev/AuthKey_{KEY_ID}.p8"))).read_text()
def token():
    return jwt.encode({"iss":ISSUER,"iat":int(time.time()),"exp":int(time.time())+1100,"aud":"appstoreconnect-v1"},KEY,algorithm="ES256",headers={"kid":KEY_ID})
def call(method,path,body=None):
    url=path if path.startswith("http") else "https://api.appstoreconnect.apple.com"+path
    r=requests.request(method,url,headers={"Authorization":"Bearer "+token(),"Content-Type":"application/json"},data=json.dumps(body) if body is not None else None)
    try: j=r.json()
    except Exception: j={}
    if r.status_code>=400: print("HTTP",r.status_code,json.dumps(j)[:1500],file=sys.stderr)
    return j
if __name__=="__main__":
    print(json.dumps(call(sys.argv[1],sys.argv[2],json.loads(sys.argv[3]) if len(sys.argv)>3 else None),ensure_ascii=False,indent=1))
