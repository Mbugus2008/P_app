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

session = requests.Session()
session.auth = (USERNAME, PASSWORD)
json_headers = {"Accept": "application/json", "Content-Type": "application/json"}


def request_json(url: str):
    r = session.get(url, headers={"Accept": "application/json"}, timeout=60)
    r.raise_for_status()
    return r.json()


def fetch_existing_nos():
    nos = []
    url = BASE_URL + "?$select=No"
    while url:
        data = request_json(url)
        rows = data.get("value", [])
        for row in rows:
            n = row.get("No")
            if n is not None:
                nos.append(int(n))
        url = data.get("@odata.nextLink")
    return nos


def delete_existing(nos):
    failed = []
    for i, no in enumerate(nos, 1):
        del_url = f"{BASE_URL}(No={no})"
        r = session.delete(del_url, headers={"If-Match": "*", "Accept": "application/json"}, timeout=60)
        if r.status_code not in (200, 202, 204):
            failed.append((no, r.status_code, r.text[:300]))
        if i % 200 == 0:
            print(f"Deleted {i}/{len(nos)}", flush=True)
    return failed


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
    raise ValueError(f"Unrecognized date value: {v!r}")


def parse_float(v):
    if v is None or v == "":
        return 0.0
    return float(v)


def build_payload(row):
    date_val, member_no, member_name, _season, crop_type, net_weight = row
    d = parse_date(date_val)
    kg = parse_float(net_weight)
    member_no_txt = "" if member_no is None else str(member_no).strip()
    member_name_txt = "" if member_name is None else str(member_name).strip()
    crop_type_txt = "CHERRY" if crop_type is None or str(crop_type).strip() == "" else str(crop_type).strip().upper()

    return {
        "Farmers_Number": member_no_txt,
        "Farmers_Name": member_name_txt,
        "Collections_Date": d.isoformat(),
        "Collection_Time": d.isoformat() + "T00:00:00Z",
        "Collection_Number": "",
        "Coffee_Type": crop_type_txt,
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
        "Comments": "Uploaded from paul use.xlsx"
    }


def upload_rows():
    wb = openpyxl.load_workbook(XLSX_PATH, data_only=True)
    ws = wb.active

    uploaded = 0
    failed = []

    for idx, row in enumerate(ws.iter_rows(min_row=2, values_only=True), start=2):
        if row is None or all(v is None or str(v).strip() == "" for v in row):
            continue
        try:
            payload = build_payload(row)
            r = session.post(BASE_URL, headers=json_headers, data=json.dumps(payload), timeout=60)
            if r.status_code not in (200, 201, 202, 204):
                failed.append((idx, r.status_code, r.text[:500]))
            else:
                uploaded += 1
        except Exception as exc:
            failed.append((idx, -1, str(exc)))

        if (idx - 1) % 200 == 0:
            print(f"Processed row {idx - 1}", flush=True)

    return uploaded, failed


def patch_factory_crop():
    rows = request_json(BASE_URL + "?$select=No").get("value", [])
    # Handle paging too
    url = BASE_URL + "?$select=No"
    all_rows = []
    while url:
        data = request_json(url)
        all_rows.extend(data.get("value", []))
        url = data.get("@odata.nextLink")

    patched = 0
    failed = []
    for i, row in enumerate(all_rows, 1):
        no = row.get("No")
        if no is None:
            continue
        patch_url = f"{BASE_URL}(No={int(no)})"
        r = session.patch(
            patch_url,
            headers={"Accept": "application/json", "Content-Type": "application/json", "If-Match": "*"},
            json={"Factory": FACTORY_VALUE, "Crop": CROP_VALUE},
            timeout=60,
        )
        if r.status_code not in (200, 204):
            failed.append((no, r.status_code, r.text[:300]))
        else:
            patched += 1
        if i % 200 == 0:
            print(f"Patched {i}/{len(all_rows)}", flush=True)

    return patched, failed


def verify_sample():
    data = request_json(BASE_URL + "?$top=500")
    rows = data.get("value", [])
    factory_ok = sum(1 for x in rows if str(x.get("Factory", "")).strip() == FACTORY_VALUE)
    crop_ok = sum(1 for x in rows if str(x.get("Crop", "")).strip() == CROP_VALUE)
    return len(rows), factory_ok, crop_ok


if __name__ == "__main__":
    print("Fetching existing records...", flush=True)
    existing_nos = fetch_existing_nos()
    print(f"Existing records found: {len(existing_nos)}", flush=True)

    if existing_nos:
        print("Deleting existing records...", flush=True)
        delete_failed = delete_existing(existing_nos)
        print(f"Delete complete. Failed deletes: {len(delete_failed)}", flush=True)
    else:
        delete_failed = []

    print("Uploading workbook rows...", flush=True)
    uploaded_count, upload_failed = upload_rows()
    print(f"Upload complete. Uploaded: {uploaded_count}, Failed: {len(upload_failed)}", flush=True)

    print("Patching Factory/Crop across all rows...", flush=True)
    patched_count, patch_failed = patch_factory_crop()
    print(f"Patch complete. Patched: {patched_count}, Failed: {len(patch_failed)}", flush=True)

    sample_total, sample_factory_ok, sample_crop_ok = verify_sample()
    print(f"Verify sample size: {sample_total}", flush=True)
    print(f"Verify sample Factory=KARUNDU: {sample_factory_ok}", flush=True)
    print(f"Verify sample Crop=2026/2027: {sample_crop_ok}", flush=True)

    if delete_failed:
        print("Delete failures (first 10):", flush=True)
        for item in delete_failed[:10]:
            print(item, flush=True)

    if upload_failed:
        print("Upload failures (first 10):", flush=True)
        for item in upload_failed[:10]:
            print(item, flush=True)

    if patch_failed:
        print("Patch failures (first 10):", flush=True)
        for item in patch_failed[:10]:
            print(item, flush=True)
