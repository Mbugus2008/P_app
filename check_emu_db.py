import sqlite3

c = sqlite3.connect('emu_parcels.db')
cur = c.cursor()

# Paid Today for KITENGELA on 12th, Receiver-only (mirror of app query)
cur.execute("""
    SELECT COUNT(*) FROM parcels
    WHERE To_Location = 'KITENGELA'
      AND Payment_Date IS NOT NULL
      AND TRIM(Payment_Date) != ''
      AND Payment_Date >= '2026-08-12T00:00:00'
      AND Payment_Date <= '2026-08-12T23:59:59.999'
      AND Date_sent < '2026-08-12T00:00:00'
      AND WhoToPay = 'Receiver'
""")
print('KITENGELA PaidToday 12th (Receiver):', cur.fetchone()[0])

cur.execute("""
    SELECT COUNT(*) FROM parcels
    WHERE To_Location = 'GTWLL ATHI'
      AND Payment_Date IS NOT NULL
      AND TRIM(Payment_Date) != ''
      AND Payment_Date >= '2026-08-12T00:00:00'
      AND Payment_Date <= '2026-08-12T23:59:59.999'
      AND Date_sent < '2026-08-12T00:00:00'
      AND WhoToPay = 'Receiver'
""")
print('ATHI PaidToday 12th (Receiver):', cur.fetchone()[0])

cur.execute("SELECT COUNT(*) FROM parcels")
print('Total rows in device parcels:', cur.fetchone()[0])

cur.execute("PRAGMA table_info(parcels)")
cols = [r[1] for r in cur.fetchall()]
print('Has WhoToPay col:', 'WhoToPay' in cols)
