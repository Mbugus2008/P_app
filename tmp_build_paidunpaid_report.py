"""Rebuild the PARCEL FOLLOW UP report with explicit PAID / UNPAID columns.

Source:
  - the PDF-extracted text (document numbers + the 'Status Report from Customer'
    comment per row)
  - live API data per parcel (paid flag, amount, amounts, parties, dates)

Output: an .xlsx next to the original report.
"""
import json
import re
import ssl
import sys
import time
import urllib.request

from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter

API = "https://nav.trimline.co.ke:4013/api/Parcel/nav/parcels/{}"
HEADERS = {"X-Client-Identifier": "REMBOCLASIC"}

COMMENTS = [
    "NO RESPONSE/NOT PICKING PHONE",
    "RETURNED BACK TO THE CUSTOMER",
    "WRONG NUMBER/PARCEL IN THE STORE",
    "LOST BY CONDUCTOR",
    "RETURN TO SENDER",
    "LOST PARCEL",
    "SYSTEM TEST",
    "TO COLLECT",
    "UNCOLLECTED",
    "IN TRANSIT",
    "COLLECTED",
]

SRC = r"D:\Projects2\Parcel\ParcelApp\parcel_followup_17092026.txt"
OUT = r"D:\Karai\Rembo\Reports\PARCEL FOLLOW UP REPORT AS AT 17.09.2026 - PAID-UNPAID.xlsx"


def load_source_rows():
    rows = []
    with open(SRC, encoding="utf-8") as fh:
        for line in fh:
            line = line.rstrip()
            m = re.match(r"^([A-Z]{3}\d{7})\s+", line)
            if not m:
                continue
            doc = m.group(1)
            comment = ""
            for c in COMMENTS:
                if line.endswith(c):
                    comment = c
                    break
            rows.append((doc, comment))
    return rows


def read(d, *keys):
    for k in keys:
        if k in d:
            return d[k]
        lower = k.lower()
        for kk, vv in d.items():
            if kk.lower() == lower:
                return vv
    return None


def fetch(doc):
    req = urllib.request.Request(API.format(doc), headers=HEADERS)
    ctx = ssl.create_default_context()
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=60, context=ctx) as resp:
                payload = json.loads(resp.read().decode("utf-8"))
            item = payload.get("contents") if isinstance(payload, dict) else None
            if item is None:
                item = payload
            return item
        except Exception as exc:  # noqa: BLE001
            if attempt == 2:
                print(f"  {doc}: fetch failed -> {exc}")
                return None
            time.sleep(1.5)
    return None


def build_flag(comment, status, paid, amount):
    s = (status or "").lower()
    if comment == "SYSTEM TEST":
        return "test parcel - delete/close"
    if comment == "COLLECTED":
        if not paid:
            return "CUSTOMER SAYS COLLECTED - UNPAID IN SYSTEM (chase payment)"
        if s.startswith("waiting"):
            return "PAID but system still Waiting_Collection"
        return ""
    if comment in ("LOST PARCEL", "LOST BY CONDUCTOR"):
        return f"LOSS reported - system: {status}, {'paid' if paid else 'unpaid'}"
    if comment in ("TO COLLECT", "UNCOLLECTED", "NO RESPONSE/NOT PICKING PHONE"):
        if paid and s == "collected":
            return "resolved after report (collected + paid)"
        if paid:
            return "PAID since report"
        return ""
    return ""


def main():
    source = load_source_rows()
    print(f"rows in source report: {len(source)}")

    table = []
    for doc, comment in source:
        p = fetch(doc)
        if p is None:
            table.append((doc, comment, None))
            continue
        table.append((doc, comment, p))
        time.sleep(0.1)

    wb = Workbook()
    ws = wb.active
    ws.title = "Details"

    headers = [
        "Document No", "Date sent", "Sender Name", "Sender Phone",
        "From", "To", "Receiver Name", "Receiver Phone", "Vehicle",
        "Date Delivered", "Amount (KES)", "PAID (KES)", "UNPAID (KES)",
        "Who to Pay", "Paid At", "Payment Method", "Created By",
        "Status", "Status Report from Customer", "Flag",
    ]
    ws.append(headers)
    header_fill = PatternFill("solid", fgColor="1F4E78")
    for col in range(1, len(headers) + 1):
        cell = ws.cell(row=1, column=col)
        cell.font = Font(bold=True, color="FFFFFF")
        cell.fill = header_fill
        cell.alignment = Alignment(horizontal="center", vertical="center")

    unpaid_fill = PatternFill("solid", fgColor="FCE4E4")
    paid_fill = PatternFill("solid", fgColor="E4F3E4")

    tot_paid = 0.0
    tot_unpaid = 0.0
    n_paid = 0
    n_unpaid = 0
    chase = []
    agents = {}
    cats = {}

    for doc, comment, p in table:
        if p is None:
            ws.append([doc, "", "", "", "", "", "", "", "", "", "", "", "?", "", "", "", "", "API FETCH FAILED", comment])
            continue

        amount = read(p, "amount_Paid", "amount_paid") or 0
        paid_flag = bool(read(p, "paid"))
        who = read(p, "who_to_pay", "who_To_Pay") or ""

        if paid_flag:
            paid_k = amount
            unpaid_k = None
            n_paid += 1
            tot_paid += amount
        else:
            paid_k = None
            unpaid_k = amount
            n_unpaid += 1
            tot_unpaid += amount

        row = [
            read(p, "document_No", "Document_No"),
            (read(p, "date_sent") or "")[:10],
            read(p, "sender_Name"),
            read(p, "sender_Phone"),
            read(p, "from"),
            read(p, "to"),
            read(p, "receiver_Name"),
            read(p, "receiver_Phone"),
            read(p, "vehicle"),
            (read(p, "date_Delivered") or "")[:10],
            amount,
            paid_k if paid_k is not None else "",
            unpaid_k if unpaid_k is not None else "",
            who,
            (read(p, "payment_Date") or "")[:10] if read(p, "payment_Date") else "",
            read(p, "payment_Method") or "",
            read(p, "created_By"),
            read(p, "status"),
            comment,
            build_flag(comment, read(p, "status"), paid_flag, amount),
        ]
        ws.append(row)

        flag = build_flag(comment, read(p, "status"), paid_flag, amount)
        by = (read(p, "created_By") or "(unknown)").strip()
        st = agents.setdefault(
            by,
            {"parcels": 0, "paid_n": 0, "paid_k": 0.0, "unpaid_n": 0, "unpaid_k": 0.0,
             "chase_n": 0, "chase_k": 0.0, "chase_docs": []},
        )
        st["parcels"] += 1
        if paid_flag:
            st["paid_n"] += 1
            st["paid_k"] += amount
        else:
            st["unpaid_n"] += 1
            st["unpaid_k"] += amount
        if comment == "COLLECTED" and not paid_flag:
            st["chase_n"] += 1
            st["chase_k"] += amount
            st["chase_docs"].append(f"{doc} ({amount:,.0f})")
            chase.append((doc, amount, by, read(p, "status")))
        cs = cats.setdefault(
            comment,
            {"n": 0, "paid_n": 0, "paid_k": 0.0, "unpaid_n": 0, "unpaid_k": 0.0},
        )
        cs["n"] += 1
        if paid_flag:
            cs["paid_n"] += 1
            cs["paid_k"] += amount
        else:
            cs["unpaid_n"] += 1
            cs["unpaid_k"] += amount

        r = ws.max_row
        if unpaid_k is not None and unpaid_k > 0:
            ws.cell(row=r, column=13).fill = unpaid_fill
        if paid_k is not None and paid_k > 0:
            ws.cell(row=r, column=12).fill = paid_fill

    # totals row
    ws.append([])
    ws.append(["", "", "", "", "", "", "", "", "", "TOTALS",
               n_paid + n_unpaid, tot_paid, tot_unpaid])
    tr = ws.max_row
    for col in (12, 13, 11):
        ws.cell(row=tr, column=col).font = Font(bold=True)

    widths = [12, 10, 16, 14, 12, 12, 16, 14, 12, 12, 11, 11, 12, 11, 10, 12, 11, 18, 32, 46]
    for i, w in enumerate(widths, start=1):
        ws.column_dimensions[get_column_letter(i)].width = w
    ws.freeze_panes = "A2"

    # ---------------- Breakdown sheet (placed first) ----------------
    bd = wb.create_sheet("Breakdown", 0)
    bd["A1"] = "PARCEL FOLLOW UP - BREAKDOWN BY AGENT"
    bd["A1"].font = Font(bold=True, size=14)
    bd["A2"] = "Customer comments: as at 17.09.2026 report | Paid/Unpaid + system status: fetched live"
    bd["A3"] = (f"Total parcels: {n_paid + n_unpaid}    PAID: {n_paid} = KES {tot_paid:,.2f}    "
                f"UNPAID: {n_unpaid} = KES {tot_unpaid:,.2f}")
    bd["A3"].font = Font(bold=True)
    bd["A5"] = "Collected per customer but UNPAID in system:"
    bd["A5"].font = Font(bold=True, color="C00000")
    bd["A6"] = f"{len(chase)} parcels = KES {sum(c[1] for c in chase):,.2f}"

    bd.append([])
    bd.append([])
    bd.append([
        "Agent", "Parcels", "Paid (n)", "Paid (KES)", "Unpaid (n)", "Unpaid (KES)",
        "Collected-but-Unpaid (n)", "Collected-but-Unpaid (KES)",
        "Documents (collected-but-unpaid)",
    ])
    for col in range(1, 10):
        c = bd.cell(row=bd.max_row, column=col)
        c.font = Font(bold=True, color="FFFFFF")
        c.fill = header_fill
        c.alignment = Alignment(horizontal="center", vertical="center")

    for agent in sorted(agents):
        st = agents[agent]
        bd.append([
            agent, st["parcels"], st["paid_n"], st["paid_k"], st["unpaid_n"],
            st["unpaid_k"], st["chase_n"], st["chase_k"], ", ".join(st["chase_docs"]),
        ])

    bd.append(["TOTAL", n_paid + n_unpaid, n_paid, tot_paid, n_unpaid, tot_unpaid,
               len(chase), sum(c[1] for c in chase), ""])
    for col in range(1, 10):
        bd.cell(row=bd.max_row, column=col).font = Font(bold=True)

    bd.append([])
    bd.append(["Status Report from Customer", "Count", "PAID (n)", "PAID (KES)", "UNPAID (n)", "UNPAID (KES)"])
    for col in range(1, 7):
        c = bd.cell(row=bd.max_row, column=col)
        c.font = Font(bold=True, color="FFFFFF")
        c.fill = header_fill
    for comment in sorted(cats, key=lambda k: -cats[k]["n"]):
        cs = cats[comment]
        bd.append([comment, cs["n"], cs["paid_n"], cs["paid_k"], cs["unpaid_n"], cs["unpaid_k"]])
    bd.append(["TOTAL", n_paid + n_unpaid, n_paid, tot_paid, n_unpaid, tot_unpaid])
    for col in range(1, 7):
        bd.cell(row=bd.max_row, column=col).font = Font(bold=True)

    bd_widths = [14, 9, 9, 11, 9, 11, 22, 22, 70]
    for i, w in enumerate(bd_widths, start=1):
        bd.column_dimensions[get_column_letter(i)].width = w

    saved = None
    candidates = [OUT, OUT.replace(".xlsx", " v2.xlsx"), OUT.replace(".xlsx", " v3.xlsx"),
                  OUT.replace(".xlsx", f" {time.strftime('%H%M%S')}.xlsx")]
    for candidate in candidates:
        try:
            wb.save(candidate)
            saved = candidate
            break
        except PermissionError:
            print(f"  locked (open in Excel): {candidate}")
    if saved is None:
        raise RuntimeError("could not save - close the report in Excel and retry")
    if saved != OUT:
        print("original file was locked; wrote:", saved)
    print("saved:", saved)
    print(f"paid rows:   {n_paid}   total PAID:   {tot_paid:,.2f}")
    print(f"unpaid rows: {n_unpaid}   total UNPAID: {tot_unpaid:,.2f}")
    print()
    print("breakdown by agent:")
    for agent in sorted(agents):
        st = agents[agent]
        print(f"  {agent:<10} parcels={st['parcels']:<3} paid={st['paid_n']} (KES {st['paid_k']:,.0f})  "
              f"unpaid={st['unpaid_n']} (KES {st['unpaid_k']:,.0f})  "
              f"collected-unpaid={st['chase_n']} (KES {st['chase_k']:,.0f})")
    print()
    print("collected-but-unpaid documents:")
    for agent in sorted(agents):
        docs = agents[agent]["chase_docs"]
        if docs:
            print(f"  {agent}: {', '.join(docs)}")


if __name__ == "__main__":
    sys.exit(main())
