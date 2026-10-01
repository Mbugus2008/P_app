"""Extract text + annotation/comment content from a PDF."""
import sys

from pypdf import PdfReader

path = sys.argv[1] if len(sys.argv) > 1 else (
    r"d:\Karai\Rembo\Reports\PARCEL FOLLOW UP REPORT AS AT 17.09.2026.pdf"
)

reader = PdfReader(path)
print(f"pages: {len(reader.pages)}")

for i, page in enumerate(reader.pages):
    print(f"\n{'=' * 70}\nPAGE {i + 1}\n{'=' * 70}")
    text = page.extract_text() or ""
    print(text)

    # annotations (comments/notes/highlights) attached to this page
    annots = page.get("/Annots")
    if annots:
        print(f"\n--- annotations on page {i + 1} ---")
        for annot in annots:
            obj = annot.get_object()
            if obj is None:
                continue
            atype = obj.get("/Subtype")
            content = obj.get("/Contents")
            author = obj.get("/T")
            print(f"[{atype}] author={author} text={content!r}")

# document-level embedded files / attachments, just in case
try:
    if reader.attachments:
        print("\n--- embedded attachments ---")
        for name, blobs in reader.attachments.items():
            print(name, [len(b) for b in blobs])
except Exception as e:
    print("attachments check failed:", e)
