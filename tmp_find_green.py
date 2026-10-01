from PIL import Image

img = Image.open(r"D:\Projects2\Parcel\ParcelApp\emu_v46_batch.png").convert("RGB")
w, h = img.size
print("size:", w, h)
px = img.load()

# find the green button (dark teal-green fill)
rows = {}
for y in range(0, h, 3):
    for x in range(0, w, 3):
        r, g, b = px[x, y]
        if r < 90 and 90 < g < 160 and b < 130:
            rows.setdefault(y, []).append(x)

bands = []
cur = None
for y in sorted(rows):
    xs = rows[y]
    if cur and y - cur["end"] <= 20:
        cur["end"] = y
        cur["xs"].extend(xs)
    else:
        if cur:
            bands.append(cur)
        cur = {"start": y, "end": y, "xs": list(xs)}
if cur:
    bands.append(cur)

for b in bands:
    xs = b["xs"]
    width = max(xs) - min(xs)
    height = b["end"] - b["start"]
    if width > 150 and height > 60:
        print(f"green button: center=({(max(xs)+min(xs))//2}, {(b['start']+b['end'])//2}) "
              f"x {min(xs)}..{max(xs)} y {b['start']}..{b['end']}")
