"""Weekly: remove free trial. Yearly: replace 3-day trial with 7-day trial in every territory it had."""
import sys; sys.path.insert(0, __file__.rsplit("/",1)[0])
from asc import call
WEEKLY, YEARLY = "6790114446", "6790114172"
def offers(sid):
    url=f"/v1/subscriptions/{sid}/introductoryOffers?limit=200&include=territory"; out=[]
    while url:
        r=call("GET",url); out+=r["data"]; url=r.get("links",{}).get("next")
    return out
# yearly territories (before deleting)
yo=offers(YEARLY)
terr=[o["relationships"]["territory"]["data"]["id"] for o in yo]
print("yearly offers",len(yo), "durations", {o["attributes"]["duration"] for o in yo})
for sid in (WEEKLY, YEARLY):
    for o in offers(sid): call("DELETE", f"/v1/subscriptionIntroductoryOffers/{o['id']}")
ok=0
for t in terr:
    r=call("POST","/v1/subscriptionIntroductoryOffers",{"data":{"type":"subscriptionIntroductoryOffers","attributes":{"duration":"ONE_WEEK","offerMode":"FREE_TRIAL","numberOfPeriods":1},
      "relationships":{"subscription":{"data":{"type":"subscriptions","id":YEARLY}},"territory":{"data":{"type":"territories","id":t}}}}})
    ok+="data" in r
print("yearly 7-day offers created",ok,"/",len(terr)); print("weekly left",len(offers(WEEKLY)))
