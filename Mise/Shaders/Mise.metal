#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Every effect here was tuned frame-by-frame against reference renders in
// tools/frameaudit (numpy ports of this exact math). Constants are not
// arbitrary — change them there first, look at the frames, then port back.

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

// ---------- ambientField (colorEffect) ----------
// The page itself: near-black warm field, one huge candle glow drifting
// imperceptibly in the upper third, a faint counter-glow lower right,
// vignette, static paper grain. Replaces the old MeshGradient.
[[ stitchable ]] half4 ambientField(float2 pos, half4 color, float2 size, float time) {
    if (color.a <= 0.0) { return color; }
    float2 uv = pos / max(size, float2(1.0));

    float3 base = float3(0.078, 0.067, 0.051) * 0.92; // ink * 0.92

    // Primary glow — drifts on a decades-slow lissajous.
    float gx = 0.32 + 0.05 * sin(time * 0.05);
    float gy = 0.16 + 0.04 * cos(time * 0.041);
    float2 d1 = (uv - float2(gx, gy)) * float2(1.0, 1.35);
    float glow1 = exp(-dot(d1, d1) * 2.1);
    base += glow1 * float3(0.055, 0.040, 0.022);

    // Counter-glow — lower right, cooler umber.
    float2 d2 = (uv - float2(0.85, 0.95)) * float2(1.0, 1.2);
    float glow2 = exp(-dot(d2, d2) * 2.6);
    base += glow2 * float3(0.020, 0.014, 0.010);

    // Vignette.
    float2 c = uv - float2(0.5, 0.46);
    float vig = 1.0 - 0.30 * smoothstep(0.30, 0.95, length(c));
    base *= vig;

    // Static paper grain — kills banding on OLED.
    base += (hash21(pos) - 0.5) * 0.014;

    return half4(half3(base), color.a);
}

// ---------- stillLife (colorEffect) ----------
// Placeholder while a photo generates: a dim studio waiting for the shot.
// A key light breathes over the surface; fine live grain. No skeleton bands.
[[ stitchable ]] half4 stillLife(float2 pos, half4 color, float2 size, float time) {
    if (color.a <= 0.0) { return color; }
    float2 uv = pos / max(size, float2(1.0));
    float3 out = float3(color.rgb);

    float breathe = 0.5 + 0.5 * sin(time * 0.78); // ~8s period
    float2 d = uv - float2(0.36, 0.30);
    float key = exp(-dot(d, d) * 3.2) * (0.045 + 0.035 * breathe);
    out += key * float3(1.06, 1.0, 0.88);

    float2 c = uv - 0.5;
    out *= 1.0 - 0.16 * smoothstep(0.25, 0.85, length(c));

    out += (hash21(pos + floor(time * 18.0)) - 0.5) * 0.022;
    return half4(half3(out), color.a);
}

// ---------- filmDevelop (layerEffect) ----------
// A photograph developing: present from frame one as a dark warm print,
// highlights emerge first, focus resolves soft -> sharp, silver grain
// dissolves as it settles. progress 0 -> 1.
[[ stitchable ]] half4 filmDevelop(float2 pos, SwiftUI::Layer layer, float2 size, float progress, float time) {
    half4 px = layer.sample(pos);
    if (progress >= 1.0) { return px; }
    float2 uv = pos / max(size, float2(1.0));
    float p = smoothstep(0.0, 1.0, clamp(progress, 0.0, 1.0));

    // Soft-to-sharp: 5-tap cross blur, radius collapsing with progress.
    float radius = (1.0 - p) * (1.0 - p) * 6.0;
    float3 soft;
    if (radius > 0.01) {
        // Shrink offsets near the layer edge so we never sample outside.
        float2 m = min(pos, size - pos);
        float guard = clamp(min(m.x, m.y) / max(radius, 0.001), 0.0, 1.0);
        float r = radius * guard;
        float3 acc = float3(layer.sample(pos).rgb) * 0.4;
        acc += float3(layer.sample(pos + float2( r, 0)).rgb) * 0.15;
        acc += float3(layer.sample(pos + float2(-r, 0)).rgb) * 0.15;
        acc += float3(layer.sample(pos + float2(0,  r)).rgb) * 0.15;
        acc += float3(layer.sample(pos + float2(0, -r)).rgb) * 0.15;
        soft = acc;
    } else {
        soft = float3(px.rgb);
    }

    // Development order: highlights first, organic frontier.
    float lum = dot(soft, float3(0.299, 0.587, 0.114));
    float fine = vnoise(uv * 60.0) * 0.6 + vnoise(uv * 18.0 + 7.0) * 0.4;
    float gate = (1.0 - lum) * 0.84 + fine * 0.16;
    float dev = smoothstep(gate - 0.42, gate + 0.22, p * 1.35);

    // Undeveloped print: the image itself, crushed dark and warmed.
    float3 undeveloped = soft * 0.16 * float3(1.12, 1.0, 0.82) + float3(0.020, 0.016, 0.011);
    float3 out = mix(undeveloped, soft, dev);

    // Silver grain, strongest mid-develop.
    float g = hash21(pos + floor(time * 24.0)) - 0.5;
    out += g * 0.035 * (1.0 - p) * (0.35 + 0.65 * dev);

    // Exposure settles from 6% hot to neutral.
    out *= 1.0 + 0.06 * (1.0 - p);
    return half4(half3(out), px.a);
}

// ---------- glassRim (colorEffect) ----------
// Procedural smoked glass for chrome. Applied over the chrome's own fill
// (material + ink tint): SDF rounded-rect rim specular under a slowly
// drifting light, counter-rim, top sheen, lower inner shadow, and a gleam
// that slides along the top edge every ~22 seconds.
static float sdRoundRect(float2 pos, float2 center, float2 half_, float radius) {
    float2 q = abs(pos - center) - (half_ - radius);
    return length(max(q, 0.0)) - radius + min(max(q.x, q.y), 0.0);
}

[[ stitchable ]] half4 glassRim(float2 pos, half4 color, float2 size, float time, float radius) {
    if (color.a <= 0.0) { return color; }
    float2 center = size * 0.5;
    float2 half_ = size * 0.5;
    float d = sdRoundRect(pos, center, half_, radius);
    float inside = smoothstep(0.75, -0.75, d);
    if (inside <= 0.001) { return color; }

    // SDF gradient -> 2D normal.
    const float eps = 1.0;
    float nx = sdRoundRect(pos + float2(eps, 0), center, half_, radius)
             - sdRoundRect(pos - float2(eps, 0), center, half_, radius);
    float ny = sdRoundRect(pos + float2(0, eps), center, half_, radius)
             - sdRoundRect(pos - float2(0, eps), center, half_, radius);
    float nlen = max(length(float2(nx, ny)), 1e-5);
    nx /= nlen; ny /= nlen;

    float rim = smoothstep(-2.0, -0.35, d) * inside;

    // Light drifts around the top.
    float ang = -1.35 + 0.35 * sin(time * 0.11);
    float2 l = float2(cos(ang), sin(ang));
    float facing = clamp(nx * l.x + ny * l.y, 0.0, 1.0);
    float spec = rim * pow(facing, 2.4) * 0.26;

    float counter = rim * pow(clamp(-(nx * l.x + ny * l.y), 0.0, 1.0), 2.0) * 0.05;

    float relY = pos.y / max(size.y, 1.0);
    float sheen = inside * pow(clamp(1.0 - relY * 2.4, 0.0, 1.0), 2.0) * 0.045;

    float ishadow = inside * pow(clamp((relY - 0.62) / 0.38, 0.0, 1.0), 1.5)
                  * 0.10 * smoothstep(-7.0, -1.5, d);

    // Traveling gleam, inside-only, hugging the top edge.
    float gx = fract(time * 0.045) * (size.x + 240.0) - 120.0;
    float gleamBand = inside * smoothstep(-6.0, -0.8, d);
    float gleam = exp(-pow((pos.x - gx) / 46.0, 2.0)) * gleamBand * clamp(-ny, 0.0, 1.0) * 0.30;

    float hairline = smoothstep(1.2, 0.0, abs(d)) * (0.07 + 0.10 * clamp(-ny, 0.0, 1.0));

    float3 out = float3(color.rgb);
    out += (spec + counter + sheen + gleam) * float3(1.04, 1.0, 0.92);
    out -= ishadow * float3(0.09, 0.095, 0.10);
    out += hairline;
    return half4(half3(out), color.a);
}

// ---------- zoomRipple (distortionEffect) ----------
// Surface tension during the thread <-> timeline zoom. One low-frequency
// radial wave, capped at 3.5px, attenuated to zero within 26px of every
// edge so nothing ever samples outside the layer (verified in frameaudit:
// the old version smeared at all four edges).
[[ stitchable ]] float2 zoomRipple(float2 pos, float2 size, float progress) {
    float energy = progress * (1.0 - progress) * 4.0;
    if (energy <= 0.001) { return pos; }
    float2 center = size * 0.5;
    float2 d = pos - center;
    float r = length(d) / max(length(center), 1.0);
    float wave = sin(r * 7.0 - progress * 6.0) * energy;

    float2 m = min(pos, size - pos);
    float edge = smoothstep(0.0, 26.0, min(m.x, m.y));

    return pos + normalize(d + 0.0001) * wave * 3.5 * edge;
}
