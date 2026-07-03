#!/usr/bin/env python3
"""
Mise frame audit v2 — candidate redesigns, tuned here before porting to Metal.
Run: python3 tools/frameaudit/audit_v2.py [outdir]
"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from audit import *  # palette, helpers, mocks, sheet(), OUT
import numpy as np

OUTDIR = sys.argv[1] if len(sys.argv) > 1 else "/tmp/audit"

def luma(img):
    return img[..., 0] * 0.299 + img[..., 1] * 0.587 + img[..., 2] * 0.114

# ---------------------------------------------------------------- film develop v2
# The image is present from frame one as a dark, warm "undeveloped print".
# Highlights emerge first (like a real print in developer), detail sharpens
# from soft to crisp, grain dissolves as it settles.
def film_develop(img, progress, t):
    h, w, _ = img.shape
    pos = grid(w, h); uv = uv_of(pos, w, h)
    p = smoothstep(0.0, 1.0, progress)

    # Soft-to-sharp: emulate the 5-tap blur the Metal layerEffect will do.
    radius = (1.0 - p) ** 2 * 6.0
    if radius > 0.01:
        offs = np.array([[0,0],[1,0],[-1,0],[0,1],[0,-1]]) * radius
        acc = np.zeros_like(img)
        wsum = 0.0
        for i, o in enumerate(offs):
            wgt = 0.4 if i == 0 else 0.15
            acc += bilinear(img, np.clip(pos + o, 0, [w-1.001, h-1.001]), oob=np.zeros(3)) * wgt
            wsum += wgt
        soft = acc / wsum
    else:
        soft = img

    # Development order: highlights first, shadows last, plus fine noise so
    # the frontier is organic, never blotchy.
    lum = luma(soft)
    fine = vnoise(uv * 60.0) * 0.6 + vnoise(uv * 18.0 + 7.0) * 0.4
    gate = (1.0 - lum) * 0.84 + fine * 0.16
    dev = smoothstep(gate - 0.42, gate + 0.22, p * 1.35)

    # Undeveloped print: the image itself, crushed dark and warmed.
    undeveloped = soft * 0.16 * np.array([1.12, 1.0, 0.82]) + np.array([0.020, 0.016, 0.011])

    out = undeveloped * (1 - dev[..., None]) + soft * dev[..., None]

    # Live silver grain, strongest mid-develop, gone at rest.
    g = (hash21_metal(pos + np.floor(t * 24.0)) - 0.5)
    grain_amt = 0.035 * (1.0 - p) * (0.35 + 0.65 * dev)
    out = out + (g * grain_amt)[..., None]

    # Exposure settles from 6% hot to neutral.
    out = out * (1.0 + 0.06 * (1.0 - p))
    return out

# ---------------------------------------------------------------- still life v2
# Placeholder while a photo generates: no skeleton bands — a dim studio.
# A soft key light breathes over the empty plate; fine grain keeps it alive.
def still_life(base, t):
    h, w, _ = base.shape
    pos = grid(w, h); uv = uv_of(pos, w, h)
    out = base.copy()

    # Key light from upper-left, breathing very slowly (8s period).
    breathe = 0.5 + 0.5 * np.sin(t * 0.78)
    d = uv - np.array([0.36, 0.30])
    key = np.exp(-((d * d).sum(-1)) * 3.2) * (0.045 + 0.035 * breathe)
    out += key[..., None] * np.array([1.06, 1.0, 0.88])

    # Corner falloff so the tile never reads flat.
    c = uv - 0.5
    vig = 1.0 - 0.16 * smoothstep(0.25, 0.85, np.sqrt((c * c).sum(-1)))
    out *= vig[..., None]

    # Fine live grain.
    g = (hash21_metal(pos + np.floor(t * 18.0)) - 0.5) * 0.022
    return out + g[..., None]

# ---------------------------------------------------------------- ripple v2
# Edge-safe surface tension: displacement is radial breathing (single low-freq
# wave), capped at 3.5px, and attenuated to zero near the layer edge.
def ripple_v2(img, progress):
    h, w, _ = img.shape
    pos = grid(w, h)
    energy = progress * (1 - progress) * 4.0
    center = np.array([w, h]) * 0.5
    d = pos - center
    r = np.sqrt((d * d).sum(-1)) / np.linalg.norm(center)
    wave = np.sin(r * 7.0 - progress * 6.0) * energy
    n = d / (np.sqrt((d * d).sum(-1))[..., None] + 1e-4)
    # Edge attenuation: zero displacement within 26px of any edge.
    ex = np.minimum(pos[..., 0], w - 1 - pos[..., 0])
    ey = np.minimum(pos[..., 1], h - 1 - pos[..., 1])
    edge = smoothstep(0.0, 26.0, np.minimum(ex, ey))
    disp = (wave * 3.5 * edge)[..., None]
    return bilinear(img, pos + n * disp)

# ---------------------------------------------------------------- ambient field v2
# Replaces MeshGradient. A near-black warm field: one large candle-warm glow
# drifting imperceptibly, corner vignette, static fine grain. Zero banding.
def ambient_field(w, h, t):
    pos = grid(w, h); uv = uv_of(pos, w, h)
    base = INK * 0.92

    # Primary glow — upper third, warm, huge and soft.
    gx = 0.32 + 0.05 * np.sin(t * 0.05)
    gy = 0.16 + 0.04 * np.cos(t * 0.041)
    d1 = (uv - np.array([gx, gy])) * np.array([1.0, 1.35])
    glow1 = np.exp(-((d1 * d1).sum(-1)) * 2.1)
    base = base + glow1[..., None] * np.array([0.055, 0.040, 0.022])

    # Counter-glow — lower right, even fainter, cooler umber.
    d2 = (uv - np.array([0.85, 0.95])) * np.array([1.0, 1.2])
    glow2 = np.exp(-((d2 * d2).sum(-1)) * 2.6)
    base = base + glow2[..., None] * np.array([0.020, 0.014, 0.010])

    # Vignette.
    c = uv - np.array([0.5, 0.46])
    vig = 1.0 - 0.30 * smoothstep(0.30, 0.95, np.sqrt((c * c).sum(-1)))
    base = base * vig[..., None]

    # Static grain — breaks banding, adds paper.
    g = (hash21_metal(pos) - 0.5) * 0.014
    return base + g[..., None]

# ---------------------------------------------------------------- glass chrome v2
# Procedural glass for the composer / floating chrome. SDF rounded-rect:
# directional rim specular, top sheen, lower inner shadow, corner glints,
# and a slow gleam that slides along the top edge.
def sdf_round_rect(pos, center, half, radius):
    q = np.abs(pos - center) - (half - radius)
    q = np.maximum(q, 0)
    return np.sqrt((q * q).sum(-1)) - radius + np.minimum(np.maximum(q[..., 0], q[..., 1]), 0) * 0

def glass_chrome(w=372, h=64, t=0.0, corner=26):
    # Background: ambient field crop so refraction context feels real.
    bgpad = 24
    W, H = w + bgpad * 2, h + bgpad * 2
    bg = ambient_field(W, H, 3.0)
    pos = grid(W, H)
    center = np.array([W / 2, H / 2])
    half = np.array([w / 2, h / 2])
    d = sdf_round_rect(pos, center, half, corner)
    inside = smoothstep(0.75, -0.75, d)

    # Fill: blurred bg stand-in (material) + ink tint.
    fill = bg * 0.55 + INK_RAISED * 0.55
    out = bg * (1 - inside[..., None]) + fill * inside[..., None]

    # SDF normal (2D gradient).
    eps = 1.0
    dx = sdf_round_rect(pos + [eps, 0], center, half, corner) - sdf_round_rect(pos - [eps, 0], center, half, corner)
    dy = sdf_round_rect(pos + [0, eps], center, half, corner) - sdf_round_rect(pos - [0, eps], center, half, corner)
    nlen = np.sqrt(dx * dx + dy * dy) + 1e-5
    nx, ny = dx / nlen, dy / nlen

    # Rim band just inside the edge.
    rim = smoothstep(-2.0, -0.35, d) * inside

    # Directional light drifts slowly around the top.
    ang = -1.35 + 0.35 * np.sin(t * 0.11)
    lx, ly = np.cos(ang), np.sin(ang)
    facing = np.clip(nx * lx + ny * ly, 0, 1)
    spec = rim * facing ** 2.4 * 0.26

    # Counter-rim (bottom) — faint cool line so the slab reads dimensional.
    counter = rim * np.clip(-(nx * lx + ny * ly), 0, 1) ** 2.0 * 0.10

    # Top sheen inside the glass.
    rel_y = (pos[..., 1] - (center[1] - half[1])) / (half[1] * 2)
    sheen = inside * np.clip(1 - rel_y * 2.4, 0, 1) ** 2 * 0.045

    # Inner shadow along the lower inside.
    ishadow = inside * np.clip((rel_y - 0.62) / 0.38, 0, 1) ** 1.5 * 0.30 * smoothstep(-7, -1.5, d)

    # Gleam that slides along the top edge (12s loop).
    gx = fract(t * 0.045) * (W + 240) - 120
    gleam_band = inside * smoothstep(-6.0, -0.8, d)   # inside-only, hugs the edge
    gleam = np.exp(-(((pos[..., 0] - gx) / 46) ** 2)) * gleam_band * np.clip(-ny, 0, 1) * 0.30

    out = out + (spec + counter * 0.5 + sheen + gleam)[..., None] * np.array([1.04, 1.0, 0.92])
    out = out - ishadow[..., None] * np.array([0.9, 0.95, 1.0]) * 0.10

    # Hairline: brighter top arc, fading down the sides.
    hairline = (smoothstep(1.2, 0.0, np.abs(d)) * (0.07 + 0.10 * np.clip(-ny, 0, 1)))
    out = out + hairline[..., None]
    return out

# ---------------------------------------------------------------- render
def main():
    os.makedirs(OUTDIR, exist_ok=True)
    photo = food_photo()

    sheet("10-film-develop-v2",
          [(f"p={p:.2f}", film_develop(photo, p, 1.23)) for p in [0.0, 0.15, 0.35, 0.55, 0.75, 1.0]],
          cols=6, scale=0.75)

    placeholder = np.zeros((340, 340, 3)) + INK_HIGH
    sheet("11-still-life-v2",
          [(f"t={t:.1f}", still_life(placeholder, t)) for t in [0.0, 2.0, 4.0, 6.0]],
          cols=4, scale=0.75)

    mock = thread_mock()
    sheet("12-ripple-v2",
          [(f"p={p:.2f}", ripple_v2(mock, p)) for p in [0.2, 0.5, 0.8]],
          cols=3, scale=0.62)

    sheet("13-ambient-field-v2",
          [(f"t={t:.0f}", ambient_field(390, 700, t)) for t in [0, 40, 80]],
          cols=3, scale=0.62)

    sheet("14-glass-chrome-v2",
          [(f"t={t:.1f}", glass_chrome(t=t)) for t in [0.0, 6.0, 12.0, 18.0]],
          cols=2, scale=1.1)

if __name__ == "__main__":
    main()
