"""Locate the orange 'Receive' buttons in the emulator screenshot.

Flutter draws its own canvas, so instead of the accessibility tree we find
pixel clusters matching the button's orange fill colour.
"""
import sys
from PIL import Image

path = sys.argv[1]
img = Image.open(path).convert("RGB")
w, h = img.size
print("image size:", w, h)

px = img.load()

# Sample the exact orange used by the Receive button from a known button pixel.
# Fall back to a generic amber filter if sampling is off.
def is_orange(r, g, b):
    return r > 220 and 120 < g < 200 and b < 80

# Collect orange pixels, bucketed into rows so we can find button bands.
rows = {}
for y in range(0, h, 4):
    for x in range(0, w, 4):
        r, g, b = px[x, y]
        if is_orange(r, g, b):
            rows.setdefault(y, []).append(x)

bands = []
current = None
for y in sorted(rows):
    xs = rows[y]
    if current and y - current["y_end"] <= 24:
        current["y_end"] = y
        current["xs"].extend(xs)
    else:
        if current:
            bands.append(current)
        current = {"y_start": y, "y_end": y, "xs": list(xs)}
if current:
    bands.append(current)

for band in bands:
    xs = band["xs"]
    width = max(xs) - min(xs)
    height = band["y_end"] - band["y_start"]
    # Receive buttons are wide pills; ignore narrow dots (status dots).
    if width > 200 and height > 60:
        cx = (max(xs) + min(xs)) // 2
        cy = (band["y_start"] + band["y_end"]) // 2
        print(f"button: x={cx} y={cy}  (x {min(xs)}..{max(xs)}, y {band['y_start']}..{band['y_end']})")
