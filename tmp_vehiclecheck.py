"""Dump dispatch/created/updated raw values for batches by vehicle."""
import sqlite3
import sys

db = sys.argv[1]
vehicles = sys.argv[2:] or ["KDX966T", "KCY 083", "KDV 566", "KCG 076Y"]

con = sqlite3.connect(db)
q = (
    "select Batch_No, Vehicle, Status, Dispatch_DateTime, Created_At, Updated_At "
    "from batches where Vehicle in ({}) order by Updated_At desc limit 8"
).format(",".join("?" for _ in vehicles))
for row in con.execute(q, vehicles):
    print(row)
con.close()
