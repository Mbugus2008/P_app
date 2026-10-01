"""Render each PDF page to PNG (and report size) so it can be viewed."""
import sys

import fitz

path = sys.argv[1]
out_prefix = sys.argv[2]
zoom = float(sys.argv[3]) if len(sys.argv) > 3 else 2.5

doc = fitz.open(path)
print("pages:", doc.page_count)
for i, page in enumerate(doc):
    print(f"page {i + 1} size: {page.rect.width:.0f} x {page.rect.height:.0f}")
    matrix = fitz.Matrix(zoom, zoom)
    pix = page.get_pixmap(matrix=matrix, alpha=False)
    out = f"{out_prefix}_p{i + 1}.png"
    pix.save(out)
    print("saved:", out, pix.width, "x", pix.height)
doc.close()
