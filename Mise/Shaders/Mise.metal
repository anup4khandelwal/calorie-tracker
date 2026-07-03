#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// ---------- shared noise helpers ----------

static float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static float vnoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + float2(1, 0));
    float c = hash21(i + float2(0, 1));
    float d = hash21(i + float2(1, 1));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// ---------- plateShimmer (colorEffect) ----------
// Placeholder life while a food image generates: a slow diagonal sheen plus
// breathing vignette over whatever base fill the view provides.
[[ stitchable ]] half4 plateShimmer(float2 pos, half4 color, float2 size, float time) {
    if (color.a <= 0.0) { return color; }
    float2 uv = pos / max(size, float2(1.0));
    // Diagonal band sweeping every ~2.4s.
    float band = fract((uv.x + uv.y) * 0.5 - time * 0.42);
    float sheen = smoothstep(0.42, 0.5, band) * (1.0 - smoothstep(0.5, 0.58, band));
    // Soft breathing toward the center.
    float2 c = uv - 0.5;
    float breathe = (0.5 + 0.5 * sin(time * 1.7)) * (1.0 - smoothstep(0.0, 0.7, length(c)));
    // Fine static grain so the surface never looks dead.
    float grain = (hash21(pos + time * 60.0) - 0.5) * 0.03;
    half3 lifted = color.rgb + half3(sheen * 0.075 + breathe * 0.035 + grain);
    return half4(lifted, color.a);
}

// ---------- grainReveal (layerEffect) ----------
// Film-grain develop: image resolves out of noise as progress 0 -> 1,
// like a print appearing in developer fluid.
[[ stitchable ]] half4 grainReveal(float2 pos, SwiftUI::Layer layer, float2 size, float progress, float time) {
    half4 px = layer.sample(pos);
    if (progress >= 1.0) { return px; }
    float2 uv = pos / max(size, float2(1.0));
    // Coarse blotches decide *when* a region develops; fine grain dithers the edge.
    float blotch = vnoise(uv * 6.0 + 3.7);
    float grain  = hash21(pos * 0.9 + floor(time * 24.0));
    float gate = blotch * 0.75 + grain * 0.25;
    // Eased progress with a slight head start so something appears immediately.
    float p = smoothstep(0.0, 1.0, progress * 1.08);
    float visible = smoothstep(gate - 0.12, gate + 0.12, p);
    // Undeveloped regions show a warm dark emulsion with sparkle.
    half3 emulsion = half3(0.10, 0.088, 0.07) + half3(grain * 0.05);
    // Developed-but-fresh pixels bloom slightly warm, settling as p -> 1.
    half boost = half((1.0 - p) * 0.18);
    half3 fresh = px.rgb * (half3(1.0) + boost * half3(1.05, 1.0, 0.9));
    half3 rgb = mix(emulsion, fresh, visible);
    return half4(rgb, px.a);
}

// ---------- liquidGlass (layerEffect) ----------
// Refractive chrome: samples the layer through a slowly-drifting lens field and
// adds a moving specular edge. Used on the composer bar and masthead chip.
[[ stitchable ]] half4 liquidGlass(float2 pos, SwiftUI::Layer layer, float2 size, float time, float strength) {
    float2 uv = pos / max(size, float2(1.0));
    // Two drifting low-frequency waves build the lens normal.
    float n1 = vnoise(uv * 3.0 + float2(time * 0.10, time * 0.13));
    float n2 = vnoise(uv * 5.0 - float2(time * 0.07, time * 0.05));
    float2 offset = (float2(n1, n2) - 0.5) * strength;
    half4 px = layer.sample(pos + offset);
    // Specular streak that slides along the top edge.
    float edge = 1.0 - smoothstep(0.0, 0.22, uv.y);
    float streakPos = fract(time * 0.05);
    float streak = exp(-pow((uv.x - streakPos) * 6.0, 2.0));
    half gleam = half(edge * (0.05 + streak * 0.10));
    return half4(px.rgb + gleam, px.a);
}

// ---------- zoomRipple (distortionEffect) ----------
// A radial wobble pinned to transition progress: strongest mid-transition,
// zero at rest, so the zoom between thread and timeline feels liquid.
[[ stitchable ]] float2 zoomRipple(float2 pos, float2 size, float progress) {
    // Bell curve over progress: nothing at 0 or 1, peak at 0.5.
    float energy = progress * (1.0 - progress) * 4.0;
    if (energy <= 0.001) { return pos; }
    float2 center = size * 0.5;
    float2 d = pos - center;
    float r = length(d) / max(length(center), 1.0);
    float wave = sin(r * 14.0 - progress * 9.0) * energy;
    return pos + normalize(d + 0.0001) * wave * 7.0;
}

// ---------- heatHaze (layerEffect) ----------
// Barely-there rising warmth on hero imagery — 1–2px vertical shimmer.
[[ stitchable ]] half4 heatHaze(float2 pos, SwiftUI::Layer layer, float2 size, float time) {
    float2 uv = pos / max(size, float2(1.0));
    float wob = vnoise(float2(uv.x * 9.0, uv.y * 5.0 - time * 0.7));
    float fade = smoothstep(0.15, 0.75, uv.y); // stronger near the bottom
    float2 offset = float2((wob - 0.5) * 1.8 * fade, 0.0);
    return layer.sample(pos + offset);
}
