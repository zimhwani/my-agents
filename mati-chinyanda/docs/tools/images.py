"""Optimise raw images into assets/img.
Usage: python3 docs/tools/images.py
Reads assets/img/raw/*, writes resized WebP (+ JPEG fallback for hero/og) to assets/img/.
Edit SLOTS to map raw files to output names and max widths."""
from PIL import Image, ImageOps
import os, sys, json
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RAW = os.path.join(ROOT, 'assets/img/raw'); OUT = os.path.join(ROOT, 'assets/img')
SLOTS = json.load(open(os.path.join(os.path.dirname(__file__), 'slots.json')))
for out_name, spec in SLOTS.items():
    src = os.path.join(RAW, spec['src'])
    if not os.path.exists(src):
        alts = [os.path.splitext(src)[0] + e for e in ('.jpeg', '.png', '.webp')]
        src = next((a for a in alts if os.path.exists(a)), src)
    if not os.path.exists(src): print('missing', src); continue
    im = ImageOps.exif_transpose(Image.open(src)).convert('RGB')
    w = spec.get('width', 1600)
    if im.width > w: im = im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)
    if 'crop' in spec:  # aspect ratio crop e.g. "3:4"
        a, b = map(int, spec['crop'].split(':')); tw, th = im.width, round(im.width * b / a)
        if th > im.height: th = im.height; tw = round(th * a / b)
        im = ImageOps.fit(im, (tw, th), Image.LANCZOS, centering=tuple(spec.get('center', (0.5, 0.35))))
    im.save(os.path.join(OUT, out_name + '.webp'), 'WEBP', quality=spec.get('q', 82), method=6)
    if spec.get('jpg'): im.save(os.path.join(OUT, out_name + '.jpg'), 'JPEG', quality=86, optimize=True, progressive=True)
    print(out_name, im.size)
