#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

namespace LifeBoardSignature {
    // Cheap value-noise hash for grain-free refraction jitter. Bounded, no texture reads.
    float hash21(float2 p) {
        p = fract(p * float2(123.34, 345.45));
        p += dot(p, p + 34.345);
        return fract(p.x * p.y);
    }

    float softCircle(float dist, float radius, float feather) {
        return 1.0 - smoothstep(radius - feather, radius + feather, dist);
    }
}

// daypartBloom: a brief radial light bloom + gentle refraction, emanating from `center`
// (normalized 0..1). Used over an atmosphere/hero fill during a manual daypart change.
// `intensity` fades the whole effect out (caller animates 1 -> 0); `tint` is the daypart light.
[[ stitchable ]] half4 LifeBoardDaypartBloom(
    float2 position,
    half4 currentColor,
    float2 size,
    float2 center,
    float time,
    float intensity,
    float3 tint
) {
    if (size.x <= 0.0 || size.y <= 0.0 || intensity <= 0.001) {
        return currentColor;
    }

    float2 uv = position / size;
    float2 toCenter = uv - center;
    // Correct for aspect so the bloom stays circular.
    toCenter.x *= size.x / size.y;
    float dist = length(toCenter);

    // Expanding ring of light plus a soft core.
    float ring = LifeBoardSignature::softCircle(dist, 0.12 + time * 0.55, 0.22);
    float core = LifeBoardSignature::softCircle(dist, time * 0.30, 0.30);
    float bloom = clamp(ring * 0.7 + core * 0.6, 0.0, 1.0) * intensity;

    // Subtle refraction wobble near the wavefront.
    float wobble = sin((dist * 26.0) - time * 6.0) * 0.5 + 0.5;
    bloom *= 0.85 + 0.15 * wobble;

    half3 lit = currentColor.rgb + half3(tint) * half(bloom * 0.6);
    return half4(min(lit, half3(1.0)), currentColor.a);
}

// evaInkReveal: a restrained shimmer + settling highlight sweeping across a freshly streamed
// token batch. `progress` is 0 (just arrived) -> 1 (settled/static). The highlight rides the
// reveal front and fades as progress completes, so finished text becomes fully static.
[[ stitchable ]] half4 LifeBoardEvaInkReveal(
    float2 position,
    half4 currentColor,
    float2 size,
    float progress,
    float newContentFraction,
    float time,
    float3 tint
) {
    if (currentColor.a <= 0.001 || size.x <= 0.0) {
        return currentColor;
    }

    float x = position.x / size.x;
    float settle = clamp(progress, 0.0, 1.0);
    // The reveal front travels left->right; a narrow band of highlight trails it.
    float front = settle;
    float band = smoothstep(front - 0.16, front, x) - smoothstep(front, front + 0.02, x);
    band = max(band, 0.0);

    // Gentle shimmer that only exists while the batch is settling.
    float shimmer = (sin((x * 18.0) - time * 5.0) * 0.5 + 0.5) * (1.0 - settle);
    float highlight = clamp(band * 0.9 + shimmer * 0.12, 0.0, 1.0) * (1.0 - settle * 0.65);

    // Streaming presentation passes the approximate fraction occupied by the
    // newly settled phrase. Bound the effect to the bottom of the transcript so
    // text the user has already read never shimmers again.
    float y = position.y / max(size.y, 1.0);
    float regionHeight = clamp(newContentFraction * 2.4, 0.18, 1.0);
    float regionStart = 1.0 - regionHeight;
    float newPhraseMask = smoothstep(regionStart, min(1.0, regionStart + 0.08), y);
    highlight *= newPhraseMask;

    half3 inked = currentColor.rgb + half3(tint) * half(highlight);
    return half4(min(inked, half3(1.0)), currentColor.a);
}

// journalMediaReveal: a soft aperture that opens from the center with slight edge refraction,
// used when protected photos/media become available. `progress` 0 (closed) -> 1 (fully open).
[[ stitchable ]] half4 LifeBoardJournalMediaReveal(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float progress
) {
    if (size.x <= 0.0 || size.y <= 0.0) {
        return layer.sample(position);
    }

    float open = clamp(progress, 0.0, 1.0);
    if (open >= 0.999) {
        return layer.sample(position);
    }

    float2 uv = position / size;
    float2 toCenter = uv - float2(0.5, 0.5);
    toCenter.x *= size.x / size.y;
    float dist = length(toCenter);

    // Aperture radius grows with progress (0.75 covers the frame diagonally).
    float radius = open * 0.85;
    float feather = 0.06 + (1.0 - open) * 0.10;
    float mask = LifeBoardSignature::softCircle(dist, radius, feather);

    // Refraction: push samples slightly inward near the aperture edge for a lens feel.
    float edge = LifeBoardSignature::softCircle(dist, radius, feather) - LifeBoardSignature::softCircle(dist, radius - feather, feather);
    float2 refract = normalize(toCenter + 1e-5) * edge * (1.0 - open) * 6.0;
    half4 sampled = layer.sample(position - refract);

    return sampled * half(mask);
}

// memoryDevelopReveal: a one-shot, progress-driven photographic development.
// It begins as warm paper/sepia and resolves into the source color through a
// soft diagonal emulsion front. There is no idle timeline and no texture read.
[[ stitchable ]] half4 LifeBoardMemoryDevelopReveal(
    float2 position,
    half4 currentColor,
    float2 size,
    float progress
) {
    if (currentColor.a <= 0.001 || size.x <= 0.0 || size.y <= 0.0) {
        return currentColor;
    }

    float developed = clamp(progress, 0.0, 1.0);
    if (developed >= 0.999) {
        return currentColor;
    }

    float2 uv = position / size;
    float grain = LifeBoardSignature::hash21(floor(position * 0.28));
    float emulsionPosition = (uv.x * 0.58 + uv.y * 0.42) + (grain - 0.5) * 0.055;
    float front = developed * 1.22 - 0.10;
    float reveal = 1.0 - smoothstep(front - 0.12, front + 0.08, emulsionPosition);

    float luminance = dot(float3(currentColor.rgb), float3(0.299, 0.587, 0.114));
    float3 paper = float3(0.94, 0.85, 0.70);
    float3 sepia = mix(paper * (0.44 + luminance * 0.62), float3(currentColor.rgb), 0.12);
    sepia += (grain - 0.5) * 0.018;
    float3 resolved = mix(sepia, float3(currentColor.rgb), reveal);
    return half4(half3(clamp(resolved, 0.0, 1.0)), currentColor.a);
}

// fastingEmberRing: a single warm ember travels around an already-rendered progress ring.
// The shader performs no texture reads and leaves transparent pixels untouched. It is applied
// only while a fast is active; accessibility and energy policy are enforced by the Swift wrapper.
[[ stitchable ]] half4 LifeBoardFastingEmberRing(
    float2 position,
    half4 currentColor,
    float2 size,
    float progress,
    float time,
    float3 tint
) {
    if (currentColor.a <= 0.001 || size.x <= 0.0 || size.y <= 0.0) {
        return currentColor;
    }

    float2 uv = (position / size) - float2(0.5);
    uv.x *= size.x / size.y;
    float angle = atan2(uv.y, uv.x);
    float normalizedAngle = fract((angle + M_PI_F * 0.5) / (M_PI_F * 2.0));
    float head = fract(clamp(progress, 0.0, 1.0) + time * 0.018);
    float delta = abs(normalizedAngle - head);
    delta = min(delta, 1.0 - delta);
    float ember = 1.0 - smoothstep(0.0, 0.055, delta);
    float breathe = 0.82 + 0.18 * sin(time * 1.7);
    half3 warm = currentColor.rgb + half3(tint) * half(ember * breathe * 0.72);
    return half4(min(warm, half3(1.0)), currentColor.a);
}
