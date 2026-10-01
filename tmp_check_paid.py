"""Dump raw payment-related fields for a few parcels to check semantics."""
import json
import ssl
import urllib.request

API = "https://nav.trimline.co.ke:4013/api/Parcel/nav/parcels/{}"
HEADERS = {"X-Client-Identifier": "REMBOCLASIC"}

DOCS = [
    "GRA0822023",  # collected, 150
    "GTW0715001",  # collected, 100, receiver
    "GTW0831001",  # collected, 200, sender
    "GRA0907025",  # to collect, 150
    "STP0916004",  # collected, 100
    "GRA0825033",  # lost parcel, 100
    "KIT0831001",  # system test
]

ctx = ssl.create_default_context()
for doc in DOCS:
    try:
        req = urllib.request.Request(API.format(doc), headers=HEADERS)
        with urllib.request.urlopen(req, timeout=60, context=ctx) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
        p = payload.get("contents", payload)
        keys = {k.lower(): v for k, v in p.items()}
        print(
            f"{doc}: status={keys.get('status')!r} paid={keys.get('paid')!r} "
            f"amount_paid={keys.get('amount_paid')!r} who_to_pay={keys.get('who_to_pay')!r} "
            f"payment_method={keys.get('payment_method')!r} payment_date={keys.get('payment_date')!r} "
            f"parcel_value={keys.get('parcel_value')!r} date_delivered={keys.get('date_delivered')!r}"
        )
    except Exception as exc:  # noqa: BLE001
        print(f"{doc}: ERROR {exc}")
