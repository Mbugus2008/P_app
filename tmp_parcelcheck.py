import sqlite3
import sys

db = sys.argv[1] if len(sys.argv) > 1 else r"D:\Projects2\Parcel\ParcelApp\emu_parcels.db"
docs = sys.argv[2:] if len(sys.argv) > 2 else ["STP0921020", "STP0924010"]

con = sqlite3.connect(db)
cur = con.cursor()

for doc in docs:
    row = cur.execute(
        "select Document_No, Status, Batch_No, Receiver_Code, Date_Delivered, Time_Delivered, Amount_Paid, Paid, is_Synced "
        "from parcels where Document_No = ?",
        (doc,),
    ).fetchone()
    print(doc, "->", row)

con.close()
