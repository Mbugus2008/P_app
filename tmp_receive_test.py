import sqlite3
import sys

db = sys.argv[1]
action = sys.argv[2] if len(sys.argv) > 2 else "check"
doc = "STP0921020"
batch_no = "BATCH-SP1A21-161044"

con = sqlite3.connect(db)
cur = con.cursor()

if action == "delete":
    print("parcel before:", cur.execute(
        "select Document_No, Status, Batch_No from parcels where Document_No = ?", (doc,)
    ).fetchall())
    cur.execute("delete from parcels where Document_No = ?", (doc,))
    con.commit()
    print("parcel after :", cur.execute(
        "select Document_No, Status from parcels where Document_No = ?", (doc,)
    ).fetchall())
else:
    print("parcel:", cur.execute(
        "select Document_No, Status, Receiver_Code, is_Synced from parcels where Document_No = ?", (doc,)
    ).fetchall())

print("batch :", cur.execute(
    "select Batch_No, Status, Received_DateTime, is_Synced from batches where Batch_No = ?", (batch_no,)
).fetchall())

con.close()
