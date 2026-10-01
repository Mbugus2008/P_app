"""Check a batch row in a pulled sqlite DB."""
import sqlite3
import sys

db = sys.argv[1]
batch = sys.argv[2] if len(sys.argv) > 2 else "BATCH-SP1A21-637536"

con = sqlite3.connect(db)
row = con.execute(
    "select Batch_No, Status, Dispatch_DateTime, Received_DateTime, Created_At, Updated_At "
    "from batches where Batch_No = ?",
    (batch,),
).fetchall()
print("batch row:", row)
con.close()
