import datetime as dt
import json
from pathlib import Path

import openpyxl
import requests

BASE_URL = "http://test.trimline.co.ke:4548/BC240/ODataV4/Company('Rugi')/DailyCollections"
USERNAME = "Philip"
PASSWORD = "Password@2030"
XLSX_PATH = Path(r"c:\Users\mbugu\Downloads\paul use.xlsx")
FACTORY_VALUE = "KARUNDU"
CROP_VALUE = "2026/2027"
COMMENT_VALUE = "Uploaded from paul use.xlsx"

s = requests.Session()
s.auth = (USERNAME, PASSWORD)


def get_json(url):
    r = s.get(url, headers={"Accept": "application/json"}, timeout=60)
    r.raise_for_status()
    return r.json()


def all_rows_select(select_fields):
    url = f"{BASE_URL}?$select={select_fields}"
    out = []
    while url:
        data = get_json(url)
        out.extend(data.get("value", []))
        url = data.get("@odata.nextLink")
    return out


def parse_date(v):
    if isinstance(v, dt.datetime):
        return v.date()
    if isinstance(v, dt.date):
        return v
    if isinstance(v, str):
        v = v.strip()
        for fmt in ("%Y-%m-%d", "%d/%m/%Y", "%m/%d/%Y", "%d-%m-%Y"):
            try:
                return dt.datetime.strptime(v, fmt).date()
            except ValueError:
                pass
    raise ValueError(f"Bad date: {v!r}")


def parse_float(v):
    if v is None or str(v).strip() == "":
        return 0.0
    return float(v)


def normalized_key(date_iso, member_no, member_name, kg):
    return f"{date_iso}|{member_no.strip()}|{member_name.strip().upper()}|{kg:.3f}"


existing = all_rows_select("No,Collections_Date,Farmers_Number,Farmers_Name,Kg_Collected")
existing_keys = set()
max_no = 0
for r in existing:
    n = r.get("No")
    if isinstance(n, int) and n > max_no:
        max_no = n
    date_iso = str(r.get("Collections_Date", "")).strip()
    member_no = str(r.get("Farmers_Number", "") or "")
    member_name = str(r.get("Farmers_Name", "") or "")
    kg = float(r.get("Kg_Collected") or 0.0)
    if date_iso:
        existing_keys.add(normalized_key(date_iso, member_no, member_name, kg))

print(f"existing_rows={len(existing)}")
print(f"existing_max_no={max_no}")
print(f"existing_unique_keys={len(existing_keys)}")

wb = openpyxl.load_workbook(XLSX_PATH, data_only=True)
ws = wb.active

next_no = max_no + 1
created = 0
skipped_as_duplicate = 0
failed = []

for i, row in enumerate(ws.iter_rows(min_row=2, values_only=True), start=2):
    if row is None or all(v is None or str(v).strip() == "" for v in row):
        continue

    date_val, member_no, member_name, _season, crop_type, net_weight = row
    try:
        d = parse_date(date_val)
    except Exception as exc:
        failed.append((i, "date_parse", str(exc)))
        continue

    date_iso = d.isoformat()
    member_no_txt = "" if member_no is None else str(member_no).strip()
    member_name_txt = "" if member_name is None else str(member_name).strip()
    kg = parse_float(net_weight)

    key = normalized_key(date_iso, member_no_txt, member_name_txt, kg)
    if key in existing_keys:
        skipped_as_duplicate += 1
        continue

    coffee_type_txt = "CHERRY" if crop_type is None or str(crop_type).strip() == "" else str(crop_type).strip().upper()

    payload = {
        "No": next_no,
        "Farmers_Number": member_no_txt,
        "Farmers_Name": member_name_txt,
        "Collections_Date": date_iso,
        "Collection_Time": date_iso + "T00:00:00Z",
        "Collection_Number": "",
        "Coffee_Type": coffee_type_txt,
        "Kg_Collected": kg,
        "Gross": kg,
        "Tare": 0,
        "No_of_Bags": 1,
        "Factory": FACTORY_VALUE,
        "Cancelled": False,
        "Paid": False,
        "Sent": False,
        "Updated": False,
        "ID_Number": "",
        "Delivered_By": member_name_txt,
        "Collect_Type": "",
        "Crop": CROP_VALUE,
        "Cumm": 0,
        "Can": "",
        "User": USERNAME,
        "Comments": COMMENT_VALUE,
    }

    r = s.post(
        BASE_URL,
        headers={"Accept": "application/json", "Content-Type": "application/json"},
        data=json.dumps(payload),
        timeout=60,
    )

    if r.status_code in (200, 201, 202, 204):
        created += 1
        existing_keys.add(key)
        next_no += 1
    else:
        body = r.text[:400]
        failed.append((i, r.status_code, body))
        if "EntityWithSameKeyExists" in body:
            next_no += 1

    if i % 300 == 0:
        print(f"processed_row={i}, created={created}, skipped={skipped_as_duplicate}, failed={len(failed)}")

rows_for_patch = all_rows_select("No")
patched = 0
patch_failed = 0
for idx, r in enumerate(rows_for_patch, start=1):
    no = r.get("No")
    if no is None:
        continue
    pr = s.patch(
        f"{BASE_URL}(No={int(no)})",
        headers={"Accept": "application/json", "Content-Type": "application/json", "If-Match": "*"},
        json={"Factory": FACTORY_VALUE, "Crop": CROP_VALUE},
        timeout=60,
    )
    if pr.status_code in (200, 204):
        patched += 1
    else:
        patch_failed += 1

    if idx % 500 == 0:
        print(f"patch_progress={idx}/{len(rows_for_patch)}")

count_resp = s.get(BASE_URL + "/$count", headers={"Accept": "text/plain"}, timeout=60)
count_resp.raise_for_status()
final_count = int(count_resp.text.strip().lstrip("\ufeff"))
sample = get_json(BASE_URL + "?$top=500").get("value", [])
sample_factory_ok = sum(1 for x in sample if str(x.get("Factory", "")).strip() == FACTORY_VALUE)
sample_crop_ok = sum(1 for x in sample if str(x.get("Crop", "")).strip() == CROP_VALUE)

print("---RESULT---")
print(f"created={created}")
print(f"skipped_duplicates={skipped_as_duplicate}")
print(f"failed={len(failed)}")
print(f"patched={patched}")
print(f"patch_failed={patch_failed}")
print(f"final_count={final_count}")
print(f"sample_factory_ok={sample_factory_ok}/{len(sample)}")
print(f"sample_crop_ok={sample_crop_ok}/{len(sample)}")
if failed:
    print("fail_first10=")
    for item in failed[:10]:
        print(item)
