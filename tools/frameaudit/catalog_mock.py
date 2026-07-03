#!/usr/bin/env python3
"""
Mocks the redesigned timeline: cutout plates floating on the ambient field
with real drop shadows and tiny centered captions — no boxes, no borders,
no gradient overlays. Used to tune spacing, shadow weight, caption sizes.

Usage: python3 tools/frameaudit/catalog_mock.py [out.png]
"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from audit import INK, CREAM, SAFFRON, hash21_metal, grid, smoothstep, to_img, food_photo
from audit_v2 import ambient_field

W, H = 390, 800

def cutout_plate(seed=0, size=300):
    """Synthetic transparent-background plate (stand-in for gpt-image output)."""
    img = food_photo(size, size)
    pos = grid(size, size); uv = pos / size
    c = uv - 0.5
    r = np.sqrt((c * c).sum(-1))
    alpha = smoothstep(0.415, 0.405, r)   # plate silhouette
    rgba = np.dstack([np.clip(img, 0, 1), alpha])
    # vary hue a touch per seed so the grid isn't uniform
    rgba[..., 0] = np.clip(rgba[..., 0] * (1 + 0.08 * np.sin(seed)), 0, 1)
    return Image.fromarray((rgba * 255).astype(np.uint8), "RGBA")

def shadow_for(plate, blur=16, alpha=140, dy=12):
    sil = plate.split()[3].point(lambda a: min(a, alpha))
    sh = Image.new("RGBA", plate.size, (0, 0, 0, 0))
    sh.putalpha(sil)
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    return sh, dy

def render(out_path):
    bg = to_img(ambient_field(W, H, 12.0)).convert("RGBA")
    d = ImageDraw.Draw(bg)
    serif = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf", 14)
    serif_big = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf", 19)
    small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 9)
    cream = tuple(int(v * 255) for v in CREAM)
    creamF = tuple(int(v * 255) for v in CREAM) + (120,)
    saff = tuple(int(v * 255) for v in SAFFRON)

    # Day header: serif date, hairline, saffron total.
    y0 = 46
    d.text((20, y0), "Today", font=serif_big, fill=cream)
    d.line([(110, y0 + 13), (300, y0 + 13)], fill=creamF, width=1)
    d.text((308, y0 + 2), "1,430", font=serif, fill=saff)

    names = ["Avocado toast", "Ramen with pork", "Cappuccino", "Poke bowl"]
    kcals = ["310 KCAL", "540 KCAL", "30 KCAL", "550 KCAL"]
    tile = 158
    gx = [20, W - 20 - tile]
    gy = [y0 + 44, y0 + 44 + tile + 64]

    for i in range(4):
        x, y = gx[i % 2], gy[i // 2]
        plate = cutout_plate(seed=i, size=tile)
        sh, dy = shadow_for(plate)
        bg.alpha_composite(sh, (x, y + dy))
        bg.alpha_composite(plate, (x, y))
        # centered captions
        name_w = d.textlength(names[i], font=serif)
        d.text((x + tile / 2 - name_w / 2, y + tile + 8), names[i], font=serif, fill=cream)
        k_w = d.textlength(kcals[i], font=small)
        d.text((x + tile / 2 - k_w / 2, y + tile + 28), kcals[i], font=small, fill=saff)

    bg.convert("RGB").save(out_path)
    print("wrote", out_path)

if __name__ == "__main__":
    render(sys.argv[1] if len(sys.argv) > 1 else "/tmp/audit/20-plate-catalog-mock.png")
