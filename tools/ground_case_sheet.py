"""contact_sheet.png from the NN_*.png of docs/wiki/shots/ground-cases (labels are drawn in the shots). Run: python3 tools/ground_case_sheet.py"""
import glob, os
from PIL import Image
d = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "docs", "wiki", "shots", "ground-cases")
fs = sorted(glob.glob(d + "/[0-9][0-9]*.png"))   # every numbered shot (labels are in the shots)
w, h = 576, 324
sheet = Image.new("RGB", (w * 3, h * ((len(fs) + 2) // 3)), (40, 40, 44))
for i, f in enumerate(fs):
    sheet.paste(Image.open(f).convert("RGB").resize((w, h), Image.LANCZOS), ((i % 3) * w, (i // 3) * h))
sheet.save(d + "/contact_sheet.png")
print(len(fs), "shots")
