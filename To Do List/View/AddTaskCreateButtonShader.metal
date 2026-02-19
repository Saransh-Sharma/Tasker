#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

// MARK: - Procedural Noise

static float hash(float n) {
    return fract(sin(n) * 753.5453123);
}

static float noise(float2 x) {
    float2 p = floor(x);
    float2 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);

    float n = p.x + p.y * 157.0;
    return mix(
        mix(hash(n + 0.0), hash(n + 1.0), f.x),
        mix(hash(n + 157.0), hash(n + 158.0), f.x),
        f.y
    );
}

static float fbm(float2 p, float3 a) {
    float v = 0.0;
    v += noise(p * a.x) * 0.50;
    v += noise(p * a.y) * 1.50;
    v += noise(p * a.z) * 0.0125;
    return v;
}

// MARK: - Line Passes

static float3 drawLines(
    float2 uv,
    float3 fbmOffset,
    float3 lineTint,
    thread const float3 *colorSet,
    float secs
) {
    float timeVal = secs * 0.1;
    float3 finalColor = float3(0.0);

    for (int i = 0; i < 4; ++i) {
        float indexAsFloat = float(i);
        float amp = 80.0 + (indexAsFloat * 0.0);
        float period = 2.0 + (indexAsFloat + 2.0);
        float thickness = mix(0.4, 0.2, noise(uv * 2.0));

        float wave = sin(uv.y + fbm(uv + timeVal * period, fbmOffset));
        float t = thickness / max(abs(wave * amp), 0.001);

        finalColor += t * colorSet[i];
    }

    for (int i = 0; i < 4; ++i) {
        float indexAsFloat = float(i);
        float amp = 40.0 + (indexAsFloat * 5.0);
        float period = 9.0 + (indexAsFloat + 2.0);
        float thickness = mix(0.10, 0.10, noise(uv * 12.0));

        float wave = sin(uv.y + fbm(uv + timeVal * period, fbmOffset));
        float t = thickness / max(abs(wave * amp), 0.001);

        finalColor += t * colorSet[i] * lineTint;
    }

    return finalColor;
}

[[ stitchable ]] half4 timeLines(
    float2 position,
    half4 color,
    float4 bounds,
    float secs,
    float tapValue,
    half4 accentPrimary,
    half4 accentSecondary,
    half4 statusSuccess,
    half4 statusWarning
) {
    (void)color;

    float2 uv = (position / bounds.zw) * 2.0 - 1.0;
    uv *= 1.5;

    float3 accentA = float3(accentPrimary.rgb);
    float3 accentB = float3(accentSecondary.rgb);
    float3 success = float3(statusSuccess.rgb);
    float3 warning = float3(statusWarning.rgb);

    float3 colorSet[4] = {
        mix(accentA, warning, 0.25),
        mix(warning, accentB, 0.55),
        mix(success, accentB, 0.45),
        mix(accentA, success, 0.55)
    };

    float lowFreqWave = sin(secs * 0.28 + uv.x * 0.9 + uv.y * 0.6) * 0.5 + 0.5;
    float spatialNoise = noise(uv * 1.35 + float2(secs * 0.05, -secs * 0.03));
    float baseBlend = clamp(mix(lowFreqWave, spatialNoise, 0.35), 0.0, 1.0);
    float3 baseColor = mix(accentA, accentB, baseBlend);
    baseColor = mix(baseColor, warning, 0.12);

    float spread = max(0.6, abs(tapValue));
    float timePulse = sin(secs) * 0.5 + 0.5;
    float pulse = mix(0.05, 0.20, timePulse);

    float3 lineColor1 = mix(accentA, warning, 0.35);
    float3 lineColor2 = mix(accentB, success, 0.35);

    float3 lineEnergy = drawLines(
        uv,
        float3(65.2, 40.0, 4.0),
        lineColor1,
        colorSet,
        secs * 0.1
    ) * pulse;

    lineEnergy += drawLines(
        uv,
        float3(5.0 * spread / 2.0, 2.1 * spread, 1.0),
        lineColor2,
        colorSet,
        secs
    );

    float3 composed = baseColor * 0.85 + lineEnergy * 0.50;
    composed = max(composed, baseColor * 0.60);
    composed = clamp(composed, 0.0, 1.0);
    return half4(half3(composed), 1.0h);
}
