#!/usr/bin/env python3
"""
Mise frame audit — renders the app's shader effects (ported 1:1 from
Mise/Shaders/Mise.metal) plus design candidates as PNG contact sheets, so
every effect can be inspected frame-by-frame and tuned before it ships.

Usage: python3 tools/frameaudit/audit.py [outdir]
"""
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

OUT = sys.argv[1] if len(sys.argv) > 1 else "/tmp/audit"

# ---------------------------------------------------------------- palette
def hex_rgb(h):
    return np.array([(h >> 16 & 255) / 255, (h >> 8 & 255) / 255, (h & 255) / 255])

INK        = hex_rgb(0x14110D)
INK_RAISED = hex_rgb(0x1E1A15)
INK_HIGH   = hex_rgb(0x2A241C)
CREAM      = hex_rgb(0xF2EDE4)
SAFFRON    = hex_rgb(0xE5A33F)
EMBER      = hex_rgb(0xC96342)
SAGE       = hex_rgb(0x9BAD84)
WHEAT      = hex_rgb(0xD9BC6E)

# ---------------------------------------------------------------- MSL ports
def fract(x): return x - np.floor(x)

def hash21(p):
    """p: (...,2) -> (...)  — exact port of the Metal helper."""
    p = fract(p * np.array([123.34, 456.21]))
    d = (p * (p + 45.32)).sum(-1)
    return fract(p[..., 0] * p[..., 1] + d - d)  # keep op order: see note below

def hash21_metal(p):
    p = fract(p * np.array([123.34, 456.21]))
    p = p + (p * (p + 45.32)).sum(-1)[..., None]
    return fract(p[..., 0] * p[..., 1])

def vnoise(p):
    i, f = np.floor(p), fract(p)
    u = f * f * (3.0 - 2.0 * f)
    def h(o): return hash21_metal(i + o)
    a, b = h(np.array([0, 0])), h(np.array([1, 0]))
    c, d = h(np.array([0, 1])), h(np.array([1, 1]))
    top = a + (b - a) * u[..., 0]
    bot = c + (d - c) * u[..., 0]
    return top + (bot - top) * u[..., 1]

def grid(w, h):
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    return np.stack([xs, ys], -1)  # position in px, like Metal's pos

def uv_of(pos, w, h):
    return pos / np.array([max(w, 1), max(h, 1)])

def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)

def to_img(rgb):
    return Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8))

# ---------------------------------------------------------------- surfaces
def food_photo(w=340, h=340):
    """Synthetic stand-in for a generated food photograph."""
    pos = grid(w, h); uv = uv_of(pos, w, h)
    img = np.zeros((h, w, 3)) + hex_rgb(0x221B13)          # umber linen
    img += (vnoise(uv * 40)[..., None] - 0.5) * 0.03        # cloth texture
    c = uv - 0.5
    r = np.sqrt((c * c).sum(-1))
    plate = smoothstep(0.40, 0.38, r)
    img = img * (1 - plate[..., None]) + plate[..., None] * hex_rgb(0x8D877D)
    rim = smoothstep(0.40, 0.36, r) - smoothstep(0.34, 0.30, r)
    img += rim[..., None] * 0.10
    blob = vnoise(uv * 6 + 2.0)
    food = smoothstep(0.24, 0.20, r) * (0.6 + 0.4 * blob)
    food_col = hex_rgb(0xB4703C) * 0.9 + hex_rgb(0xD9A050) * 0.4 * vnoise(uv * 14)[..., None]
    img = img * (1 - food[..., None]) + food[..., None] * food_col
    light = 1.0 - 0.35 * smoothstep(0.0, 1.2, np.sqrt(((uv - [0.3, 0.2]) ** 2).sum(-1)))
    return img * light[..., None]

def thread_mock(w=390, h=700):
    """Blocky mock of the chat screen (for transition/ripple audits)."""
    img = np.zeros((h, w, 3)) + INK
    pil = to_img(img); d = ImageDraw.Draw(pil)
    def cream(a): return tuple(int(v * 255) for v in CREAM) + (a,)
    d.rounded_rectangle([20, 26, 200, 40], 4, fill=tuple(int(v*255) for v in CREAM))
    d.ellipse([320, 18, 372, 70], outline=tuple(int(v*255) for v in SAFFRON), width=3)
    y = 110
    for wl in [300, 260, 180]:
        d.rounded_rectangle([20, y, 20 + wl, y + 12], 6, fill=tuple(int(v*200) for v in CREAM)); y += 24
    d.rounded_rectangle([20, y + 10, 340, y + 250], 22, fill=tuple(int(v*255) for v in INK_RAISED))
    d.rounded_rectangle([150, y + 290, 370, y + 330], 18, fill=tuple(int(v*255) for v in INK_HIGH))
    d.rounded_rectangle([16, h - 70, w - 16, h - 18], 24, outline=tuple(int(v*255) for v in INK_HIGH), width=2)
    return np.asarray(pil).astype(np.float64) / 255

# ---------------------------------------------------------------- shipped shaders (current)
def plate_shimmer(base, t):
    h, w, _ = base.shape
    pos = grid(w, h); uv = uv_of(pos, w, h)
    band = fract((uv[..., 0] + uv[..., 1]) * 0.5 - t * 0.42)
    sheen = smoothstep(0.42, 0.5, band) * (1 - smoothstep(0.5, 0.58, band))
    c = uv - 0.5
    breathe = (0.5 + 0.5 * np.sin(t * 1.7)) * (1 - smoothstep(0.0, 0.7, np.sqrt((c*c).sum(-1))))
    grain = (hash21_metal(pos + t * 60.0) - 0.5) * 0.03
    return base + (sheen * 0.075 + breathe * 0.035 + grain)[..., None]

def grain_reveal(img, progress, t):
    h, w, _ = img.shape
    pos = grid(w, h); uv = uv_of(pos, w, h)
    blotch = vnoise(uv * 6.0 + 3.7)
    grain = hash21_metal(pos * 0.9 + np.floor(t * 24.0))
    gate = blotch * 0.75 + grain * 0.25
    p = smoothstep(0.0, 1.0, np.clip(progress * 1.08, 0, 1))
    visible = smoothstep(gate - 0.12, gate + 0.12, p)
    emulsion = hex_rgb(0x1A1712) + grain[..., None] * 0.05
    boost = (1.0 - p) * 0.18
    fresh = img * (1.0 + boost * np.array([1.05, 1.0, 0.9]))
    return emulsion * (1 - visible[..., None]) + fresh * visible[..., None]

def zoom_ripple_current(img, progress):
    h, w, _ = img.shape
    pos = grid(w, h)
    energy = progress * (1 - progress) * 4.0
    center = np.array([w, h]) * 0.5
    d = pos - center
    r = np.sqrt((d * d).sum(-1)) / np.linalg.norm(center)
    wave = np.sin(r * 14.0 - progress * 9.0) * energy
    n = d / (np.sqrt((d * d).sum(-1))[..., None] + 1e-4)
    sample = pos + n * (wave * 7.0)[..., None]
    return bilinear(img, sample)

def bilinear(img, pos, oob=None):
    """Sample img at float positions; out-of-bounds -> magenta marker."""
    h, w, _ = img.shape
    x = pos[..., 0]; y = pos[..., 1]
    bad = (x < 0) | (x > w - 1) | (y < 0) | (y > h - 1)
    x = np.clip(x, 0, w - 1.001); y = np.clip(y, 0, h - 1.001)
    x0 = x.astype(int); y0 = y.astype(int)
    fx = (x - x0)[..., None]; fy = (y - y0)[..., None]
    c = (img[y0, x0] * (1-fx) * (1-fy) + img[y0, x0+1] * fx * (1-fy)
         + img[y0+1, x0] * (1-fx) * fy + img[y0+1, x0+1] * fx * fy)
    marker = np.array([1.0, 0.0, 1.0]) if oob is None else oob
    c[bad] = marker
    return c

# ---------------------------------------------------------------- contact sheet
def sheet(name, cells, cols=None, pad=14, scale=1.0):
    """cells: list of (label, np image). Saves a labeled grid."""
    cols = cols or len(cells)
    imgs = [to_img(c[1]) for c in cells]
    if scale != 1.0:
        imgs = [im.resize((int(im.width*scale), int(im.height*scale))) for im in imgs]
    cw = max(im.width for im in imgs); ch = max(im.height for im in imgs)
    rows = (len(cells) + cols - 1) // cols
    W = cols * cw + (cols + 1) * pad
    H = rows * (ch + 26) + pad
    canvas = Image.new("RGB", (W, H), (10, 9, 7))
    d = ImageDraw.Draw(canvas)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 13)
    except OSError:
        font = ImageFont.load_default()
    for i, ((label, _), im) in enumerate(zip(cells, imgs)):
        r, c = divmod(i, cols)
        x = pad + c * (cw + pad); y = pad + r * (ch + 26)
        canvas.paste(im, (x, y))
        d.text((x, y + im.height + 5), label, fill=(200, 195, 185), font=font)
    path = f"{OUT}/{name}.png"
    canvas.save(path)
    print("wrote", path)

# ---------------------------------------------------------------- contrast report
def rel_lum(rgb):
    c = np.where(rgb <= 0.03928, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]

def contrast(a, b):
    la, lb = rel_lum(a), rel_lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)

def contrast_report():
    pairs = [
        ("cream on ink",           CREAM, INK),
        ("cream 62% on ink",       CREAM * 0.62 + INK * 0.38, INK),
        ("cream 35% on ink",       CREAM * 0.35 + INK * 0.65, INK),
        ("cream 42% on ink",       CREAM * 0.42 + INK * 0.58, INK),
        ("saffron on ink",         SAFFRON, INK),
        ("ember on ink",           EMBER, INK),
        ("cream on inkRaised",     CREAM, INK_RAISED),
        ("cream 62% on inkRaised", CREAM * 0.62 + INK_RAISED * 0.38, INK_RAISED),
        ("ink on saffron (button)", INK, SAFFRON),
        ("wheat on ink",           WHEAT, INK),
        ("sage on ink",            SAGE, INK),
    ]
    print("\n=== WCAG contrast ===")
    for name, fg, bg in pairs:
        c = contrast(fg, bg)
        flag = "PASS AA" if c >= 4.5 else ("large-only" if c >= 3.0 else "FAIL")
        print(f"  {name:26s} {c:5.2f}:1   {flag}")

# ---------------------------------------------------------------- main
def main():
    import os
    os.makedirs(OUT, exist_ok=True)

    photo = food_photo()
    sheet("01-grain-reveal-current",
          [(f"p={p:.2f}", grain_reveal(photo, p, 1.23)) for p in [0.1, 0.3, 0.5, 0.7, 0.9, 1.0]],
          cols=6, scale=0.75)

    placeholder = np.zeros((340, 340, 3)) + INK_HIGH
    sheet("02-plate-shimmer-current",
          [(f"t={t:.1f}", plate_shimmer(placeholder, t)) for t in [0.0, 0.8, 1.6, 2.4]],
          cols=4, scale=0.75)

    mock = thread_mock()
    sheet("03-zoom-ripple-current",
          [(f"p={p:.2f} (magenta = out-of-bounds sample)", zoom_ripple_current(mock, p)) for p in [0.2, 0.5, 0.8]],
          cols=3, scale=0.62)

    contrast_report()

if __name__ == "__main__":
    main()
