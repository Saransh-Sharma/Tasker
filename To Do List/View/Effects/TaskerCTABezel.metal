#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

namespace TaskerMetalBezel {
    constant float PI = 3.14159265358979323846;
    constant float4 C = float4(0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439);

    float3 mod289(float3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
    float2 mod289(float2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
    float3 permute(float3 x) { return mod289(((x * 34.0) + 1.0) * x); }

    float snoise(float2 v) {
        float2 i = floor(v + dot(v, C.yy));
        float2 x0 = v - i + dot(i, C.xx);
        float2 i1 = (x0.x > x0.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
        float4 x12 = x0.xyxy + C.xxzz;
        x12.xy -= i1;
        i = mod289(i);
        float3 p = permute(permute(i.y + float3(0.0, i1.y, 1.0)) + i.x + float3(0.0, i1.x, 1.0));
        float3 m = max(0.5 - float3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
        m = m * m;
        m = m * m;
        float3 x = 2.0 * fract(p * C.www) - 1.0;
        float3 h = abs(x) - 0.5;
        float3 ox = floor(x + 0.5);
        float3 a0 = x - ox;
        m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
        float3 g;
        g.x = a0.x * x0.x + h.x * x0.y;
        g.yz = a0.yz * x12.xz + h.yz * x12.yw;
        return 130.0 * dot(m, g);
    }

    float2 rotate(float2 uv, float angle) {
        float2x2 matrix = float2x2(cos(angle), sin(angle), -sin(angle), cos(angle));
        return matrix * uv;
    }

    float3 silver(float shine) {
        float3 light = float3(0.96, 0.97, 1.00);
        float3 dark = float3(0.36, 0.39, 0.44);
        return mix(dark, light, shine);
    }

    float3 titanium(float shine) {
        float3 light = float3(0.86, 0.89, 0.95);
        float3 dark = float3(0.30, 0.33, 0.38);
        return mix(dark, light, shine);
    }

    float3 roseGold(float shine) {
        float3 light = float3(0.99, 0.84, 0.81);
        float3 dark = float3(0.58, 0.34, 0.34);
        return mix(dark, light, shine);
    }

    float3 copper(float shine) {
        float3 light = float3(0.98, 0.76, 0.58);
        float3 dark = float3(0.52, 0.27, 0.16);
        return mix(dark, light, shine);
    }
}

[[ stitchable ]] half4 TaskerLiquidMetalBezel(
    float2 position,
    half4 currentColor,
    float2 size,
    float time,
    float intensity,
    float chromatic,
    float edge,
    float palette,
    float liquid
) {
    if (currentColor.a <= 0.001 || size.x <= 0.0 || size.y <= 0.0) {
        return currentColor;
    }

    float2 uv = position / size;
    float2 centered = uv - 0.5;
    float2 rotated = TaskerMetalBezel::rotate(centered, 0.16 * TaskerMetalBezel::PI);
    float diagonal = uv.x - uv.y;

    float movingTime = time * 0.62;
    float noise = TaskerMetalBezel::snoise((uv * 3.2) + float2(0.0, movingTime * 0.38));
    float wave = 0.5 + 0.5 * sin((rotated.y + diagonal * 0.6 - movingTime) * 13.5);
    float band = smoothstep(0.18, 0.86, wave + noise * liquid * 0.32);
    float sheen = pow(band, max(0.45, edge));

    float distanceToCenter = length(centered);
    float vignette = 1.0 - smoothstep(0.14, 0.74, distanceToCenter);
    float sparkle = smoothstep(0.25, 0.9, sheen + vignette * 0.18);

    float chromaLift = chromatic * (0.35 + 0.65 * sparkle);
    float3 metal;
    if (palette >= 1.5) {
        metal = mix(TaskerMetalBezel::copper(sheen), float3(0.97, 0.84, 0.70), 0.18 + sparkle * 0.16);
        metal.r += chromaLift * 0.20;
        metal.g += chromaLift * 0.08;
        metal.b += chromaLift * 0.03;
    } else if (palette >= 0.5) {
        metal = mix(TaskerMetalBezel::roseGold(sheen), float3(0.99, 0.91, 0.88), 0.22 + sparkle * 0.18);
        metal.r += chromaLift * 0.18;
        metal.g += chromaLift * 0.05;
        metal.b += chromaLift * 0.08;
    } else {
        metal = mix(TaskerMetalBezel::titanium(sparkle), TaskerMetalBezel::silver(sheen), 0.6);
        metal.r += chromaLift * 0.12;
        metal.b += chromaLift * 0.22;
    }

    float edgeBoost = 0.85 + edge * 0.22;
    float3 color = metal * intensity * edgeBoost;

    return half4(half3(color), currentColor.a);
}

[[ stitchable ]] half4 TaskerNoisyGradient(float2 pos, SwiftUI::Layer l, float4 bounds, float time) {
    float2 size = bounds.zw;
    float2 uv = pos / size;

    // Base colors from the reference gradient sample.
    half3 peach = half3(0.9, 0.4, 0.3);
    half3 purple = half3(0.2, 0.1, 0.6);
    half3 teal = half3(0.0, 0.8, 0.8);

    // Vertical and horizontal distortion for organic motion.
    float t = uv.y + 0.2 * sin(time + uv.x * 3.0);
    float p = uv.x + 0.2 * cos(time + uv.y * 6.0);

    // Blend in a way that keeps the same palette shape as the source sample.
    half3 bottomColor = mix(purple, teal, half(clamp(p, 0.0, 1.0)));
    half3 color = mix(bottomColor, peach, half(clamp(t, 0.0, 1.0)));

    return half4(color, 1.0);
}
