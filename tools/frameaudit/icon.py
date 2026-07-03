#!/usr/bin/env python3
"""
Renders the Mise app icon (1024px) with the same ambient-field math as the
app background: warm ink, candle glow, paper grain — and the calorie ring
as the mark, swept to a golden 62%, goal tick at twelve.

Usage: python3 tools/frameaudit/icon.py <out.png>
"""
import sys
import numpy as np

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from audit import INK, SAFFRON, EMBER, CREAM, hash21_metal, grid, smoothstep, to_img

def render(size=1024):
    pos = grid(size, size)
    uv = pos / size

    # Ambient field, tuned slightly warmer for the icon.
    base = np.zeros((size, size, 3)) + INK * 0.92
    d1 = (uv - np.array([0.38, 0.24])) * np.array([1.0, 1.3])
    base += np.exp(-((d1 * d1).sum(-1)) * 2.0)[..., None] * np.array([0.075, 0.052, 0.028])
    d2 = (uv - np.array([0.85, 0.95]))
    base += np.exp(-((d2 * d2).sum(-1)) * 2.6)[..., None] * np.array([0.022, 0.015, 0.010])
    c = uv - np.array([0.5, 0.47])
    base *= (1.0 - 0.34 * smoothstep(0.28, 0.9, np.sqrt((c * c).sum(-1))))[..., None]
    base += ((hash21_metal(pos) - 0.5) * 0.012)[..., None]

    # The ring: radius 0.30, width 0.030, swept 62% from twelve o'clock.
    cc = uv - 0.5
    r = np.sqrt((cc * cc).sum(-1))
    ang = np.arctan2(cc[..., 0], -cc[..., 1])          # 0 at twelve, clockwise
    ang = np.where(ang < 0, ang + 2 * np.pi, ang)
    sweep = 0.62 * 2 * np.pi

    ring_band = smoothstep(0.0155, 0.0125, np.abs(r - 0.30))
    on_arc = smoothstep(0.06, 0.0, np.maximum(ang - sweep, 0)) * smoothstep(-0.02, 0.02, ang)
    # Track: whisper of cream where the arc hasn't reached.
    track = ring_band * 0.10
    # Arc color warms from saffron toward ember along the sweep.
    tmix = np.clip(ang / sweep, 0, 1)[..., None]
    arc_col = SAFFRON * (1 - tmix) + EMBER * tmix
    arc = (ring_band * on_arc)[..., None] * arc_col

    # Rounded arc tip: a dot at the sweep end.
    tip_ang = sweep
    tip = np.array([0.5 + 0.30 * np.sin(tip_ang), 0.5 - 0.30 * np.cos(tip_ang)])
    dt = uv - tip
    tip_dot = smoothstep(0.0155, 0.011, np.sqrt((dt * dt).sum(-1)))
    arc += tip_dot[..., None] * EMBER

    # Goal tick at twelve — top hemisphere only, or it ghosts at six.
    top = cc[..., 1] < 0
    tick = (smoothstep(0.004, 0.002, np.abs(cc[..., 0]))
            * smoothstep(0.0, 1.0, (0.345 - r) / 0.02) * smoothstep(0.0, 1.0, (r - 0.315) / 0.02)
            * top)
    out = base * (1 - track[..., None] * 3) + track[..., None] * CREAM
    out = out * (1 - (ring_band * on_arc + tip_dot)[..., None]) + arc
    out += tick[..., None] * CREAM * 0.75

    # Glow around the arc.
    glow_band = np.exp(-((r - 0.30) / 0.05) ** 2) * on_arc
    out += glow_band[..., None] * arc_col * 0.10
    return out

if __name__ == "__main__":
    out_path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/audit/icon.png"
    to_img(render()).save(out_path)
    print("wrote", out_path)
