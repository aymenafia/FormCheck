import json, sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from asc import call
APP="6790111242"
m=json.loads(pathlib.Path(__file__).parent.parent.joinpath("AppStore/metadata.json").read_text())["en-US"]
vs=call("GET",f"/v1/apps/{APP}/appStoreVersions?limit=5")["data"]
ver=next((v for v in vs if v["attributes"]["versionString"]=="1.1.0"),None)
if not ver:
    ver=call("POST","/v1/appStoreVersions",{"data":{"type":"appStoreVersions","attributes":{"platform":"IOS","versionString":"1.1.0","releaseType":"AFTER_APPROVAL"},
        "relationships":{"app":{"data":{"type":"apps","id":APP}}}}})["data"]
VER=ver["id"]; print("version",VER,ver["attributes"].get("appStoreState"))
vl=call("GET",f"/v1/appStoreVersions/{VER}/appStoreVersionLocalizations")["data"][0]["id"]
r=call("PATCH",f"/v1/appStoreVersionLocalizations/{vl}",{"data":{"type":"appStoreVersionLocalizations","id":vl,"attributes":{k:m[k] for k in ["description","keywords","promotionalText","whatsNew"]}}})
print("version loc", "ok" if "data" in r else r)
# subtitle lives on the editable appInfo
infos=call("GET",f"/v1/apps/{APP}/appInfos")["data"]
edit=[i for i in infos if i["attributes"].get("state")!="READY_FOR_DISTRIBUTION"] or infos
INFO=edit[0]["id"]; print("appInfo",INFO,edit[0]["attributes"].get("state"))
il=call("GET",f"/v1/appInfos/{INFO}/appInfoLocalizations")["data"][0]["id"]
r=call("PATCH",f"/v1/appInfoLocalizations/{il}",{"data":{"type":"appInfoLocalizations","id":il,"attributes":{"subtitle":m["subtitle"]}}})
print("subtitle", "ok" if "data" in r else r)
json.dump({"version":VER,"appInfo":INFO,"versionLoc":vl},open(pathlib.Path(__file__).parent.parent/"AppStore/asc_ids.json","w"))
