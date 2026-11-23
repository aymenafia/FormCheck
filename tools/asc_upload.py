"""Upload helpers for App Store Connect assets (screenshots, IAP review screenshot)."""
import hashlib, os, requests, time
from asc import call
def upload(create_type, rel_name, rel_type, rel_id, path, extra_attrs=None):
    data=open(path,'rb').read()
    r=call("POST",f"/v1/{create_type}",{"data":{"type":create_type,"attributes":{"fileName":os.path.basename(path),"fileSize":len(data),**(extra_attrs or {})},
        "relationships":{rel_name:{"data":{"type":rel_type,"id":rel_id}}}}})
    obj=r["data"]
    for op in obj["attributes"]["uploadOperations"]:
        chunk=data[op["offset"]:op["offset"]+op["length"]]
        requests.request(op["method"],op["url"],headers={h["name"]:h["value"] for h in op["requestHeaders"]},data=chunk).raise_for_status()
    call("PATCH",f"/v1/{create_type}/{obj['id']}",{"data":{"type":create_type,"id":obj["id"],"attributes":{"uploaded":True,"sourceFileChecksum":hashlib.md5(data).hexdigest()}}})
    return obj["id"]
