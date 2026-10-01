import sqlite3
import sys

db = sys.argv[1] if len(sys.argv) > 1 else r"D:\Projects2\Parcel\ParcelApp\emu_parcels.db"
con = sqlite3.connect(db)
cur = con.cursor()

tables = [r[0] for r in cur.execute("select name from sqlite_master where type='table'")]
print("tables:", tables)

for t in tables:
    try:
        n = cur.execute(f"select count(*) from [{t}]").fetchone()[0]
        print(f"{t}: {n} rows")
    except Exception as e:
        print(f"{t}: error {e}")

# sample parcel rows if any
try:
    rows = cur.execute("select Document_No, Status, From_Location, To_Location, Batch_No from parcels limit 5").fetchall()
    print("sample parcels:", rows)
except Exception as e:
    print("sample error:", e)

con.close()
