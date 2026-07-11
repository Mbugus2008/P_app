import openpyxl

wb = openpyxl.load_workbook('parcel.xlsx')
ws = wb.active
today = '2026-06-29'

stPaul = [list(r) for r in ws.iter_rows(min_row=2, values_only=True)
          if 'ST PAUL' in str(r[6] or '').upper() or 'ST PAUL' in str(r[7] or '').upper()]

def is_paid(r): return str(r[17] or '').lower() == 'yes'
def is_cash(r): return 'cash' in str(r[25] or '').lower()
def is_mpesa(r):
    m = str(r[25] or '').lower()
    return 'mpesa' in m or 'm-pesa' in m
def in_range(d): return d is not None and str(d)[:10] == today

sent_today = [r for r in stPaul if 'ST PAUL' in str(r[6] or '').upper() and in_range(r[2])]
recv_today = [r for r in stPaul if 'ST PAUL' in str(r[7] or '').upper() and in_range(r[2])]
paid_today = [r for r in stPaul if in_range(r[35]) and not in_range(r[2])]

print('=== ST PAUL TODAY ===')
s_t = len(sent_today)
s_p = sum(1 for r in sent_today if is_paid(r))
s_c = sum(r[16] or 0 for r in sent_today if is_cash(r))
s_m = sum(r[16] or 0 for r in sent_today if is_mpesa(r))
print(f'Sent: Total={s_t} Paid={s_p} Cash={s_c} M-Pesa={s_m}')

r_t = len(recv_today)
r_p = sum(1 for r in recv_today if is_paid(r))
r_c = sum(r[16] or 0 for r in recv_today if is_cash(r))
r_m = sum(r[16] or 0 for r in recv_today if is_mpesa(r))
print(f'Recv: Total={r_t} Paid={r_p} Cash={r_c} M-Pesa={r_m}')

pt_t = len(paid_today)
pt_p = sum(1 for r in paid_today if is_paid(r))
pt_c = sum(r[16] or 0 for r in paid_today if is_cash(r))
pt_m = sum(r[16] or 0 for r in paid_today if is_mpesa(r))
print(f'PaidToday: Total={pt_t} Paid={pt_p} Cash={pt_c} M-Pesa={pt_m}')

print(f'TOTAL: Cash={s_c+r_c+pt_c} M-Pesa={s_m+r_m+pt_m}')

print()
print('=== Paid Today details ===')
for r in paid_today[:10]:
    print(f'  {r[0]} From={r[6]} To={r[7]} Date_sent={str(r[2])[:10]} PayDate={str(r[35])[:10]} Paid={r[17]} Amt={r[16]} Method={r[25]}')
print(f'  ... ({len(paid_today)} total)')
