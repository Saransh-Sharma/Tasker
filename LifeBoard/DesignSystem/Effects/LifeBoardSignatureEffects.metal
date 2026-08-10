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

// healthSyncPulse: one bounded confirmation wave after an authorization grant or
// a user-requested sync completes. The caller drives progress from 0 -> 1 once.
[[ stitchable ]] half4 LifeBoardHealthSyncPulse(
    float2 position,
    half4 currentColor,
    float2 size,
    float progress,
    float3 tint
) {
    if (currentColor.a <= 0.001 || size.x <= 0.0 || size.y <= 0.0) {
        return currentColor;
    }
    float2 uv = position / size;
    float2 delta = uv - float2(0.5);
    delta.x *= size.x / size.y;
    float distance = length(delta);
    float front = clamp(progress, 0.0, 1.0) * 0.82;
    float ring = 1.0 - smoothstep(0.035, 0.12, abs(distance - front));
    float fade = 1.0 - clamp(progress, 0.0, 1.0);
    half3 resolved = currentColor.rgb + half3(tint) * half(ring * fade * 0.48);
    return half4(min(resolved, half3(1.0)), currentColor.a);
}

// vitalOrbWarp: a short, low-amplitude deformation for a direct interaction or
// first daily goal crossing. It has no time source and cannot become an idle loop.
[[ stitchable ]] float2 LifeBoardVitalOrbWarp(
    float2 position,
    float2 size,
    float progress
) {
    if (size.x <= 0.0 || size.y <= 0.0) {
        return position;
    }
    float phase = clamp(progress, 0.0, 1.0);
    float envelope = sin(phase * M_PI_F);
    float2 uv = (position / size) - float2(0.5);
    float radius = length(uv);
    float falloff = 1.0 - smoothstep(0.05, 0.72, radius);
    float wave = sin(radius * 24.0 - phase * 8.0);
    float2 direction = normalize(uv + 1e-5);
    return position + direction * wave * falloff * envelope * 5.0;
}

// clayPressBloom: the tactile signature. Pressing a clay surface pushes a soft
// dimple into it — the contact point darkens very slightly and a warm rim of
// displaced light pushes outward, the way a thumb pressed into real clay leaves
// a shaded well ringed by a raised lip. `progress` runs 0 -> 1 across the press;
// `center` is the touch point in normalized coordinates.
[[ stitchable ]] half4 LifeBoardClayPressBloom(
    float2 position,
    half4 currentColor,
    float2 size,
    float2 center,
    float progress,
    float3 tint
) {
    if (size.x <= 0.0 || size.y <= 0.0 || progress <= 0.001) {
        return currentColor;
    }

    float2 uv = position / size;
    float2 toCenter = uv - center;
    toCenter.x *= size.x / size.y;
    float dist = length(toCenter);

    // The dimple opens quickly and relaxes slowly, so the press reads as
    // material yielding rather than as a flash.
    float envelope = sin(progress * 3.14159265);
    float radius = 0.10 + progress * 0.34;

    // Shaded well at the contact point.
    float well = LifeBoardSignature::softCircle(dist, radius * 0.55, 0.20) * envelope;
    // Raised lip of displaced light just outside it.
    float lip = smoothstep(radius * 0.5, radius, dist) * (1.0 - smoothstep(radius, radius * 1.5, dist));
    lip *= envelope;

    half3 shaded = currentColor.rgb * half(1.0 - well * 0.10);
    half3 lifted = shaded + half3(tint) * half(lip * 0.18);
    return half4(clamp(lifted, half3(0.0), half3(1.0)), currentColor.a);
}

// daypartCrossDissolve: the screen changing time of day. A soft organic front
// sweeps diagonally across the surface carrying the incoming daypart's light,
// with a low-frequency wobble so the boundary is a weather edge rather than a
// wipe. `progress` 0 -> 1 drives the front; `tint` is the incoming light.
[[ stitchable ]] half4 LifeBoardDaypartCrossDissolve(
    float2 position,
    half4 currentColor,
    float2 size,
    float progress,
    float3 tint
) {
    if (size.x <= 0.0 || size.y <= 0.0 || progress <= 0.001 || progress >= 0.999) {
        return currentColor;
    }

    float2 uv = position / size;
    // Diagonal sweep, top-trailing to bottom-leading, matching where the
    // celestial sits.
    float axis = (uv.x * 0.38 + uv.y * 0.62);

    // Two out-of-phase sines keep the front organic without needing noise reads.
    float wobble = sin(uv.y * 7.0) * 0.035 + sin(uv.x * 4.5 + 1.7) * 0.028;
    float front = progress * 1.36 - 0.18;
    float band = smoothstep(front - 0.24, front + 0.10, axis + wobble);

    // Light is strongest at the leading edge and settles behind it.
    float edge = (1.0 - band) * smoothstep(front - 0.30, front, axis + wobble);
    float wash = (1.0 - band) * 0.5 + edge * 0.9;

    // The whole effect fades out as the transition completes so the final
    // frame is exactly the untouched destination.
    float envelope = sin(progress * 3.14159265);
    half3 lit = currentColor.rgb + half3(tint) * half(wash * 0.26 * envelope);
    return half4(min(lit, half3(1.0)), currentColor.a);
}

// completionBurst: a commitment finishing. A warm ring expands once from the
// checkmark and dissipates, replacing the CPU particle celebration. Bounded to
// a single 0 -> 1 pass; there is no looping variant on purpose.
[[ stitchable ]] half4 LifeBoardCompletionBurst(
    float2 position,
    half4 currentColor,
    float2 size,
    float2 center,
    float progress,
    float3 tint
) {
    if (size.x <= 0.0 || size.y <= 0.0 || progress <= 0.001 || progress >= 0.999) {
        return currentColor;
    }

    float2 uv = position / size;
    float2 toCenter = uv - center;
    toCenter.x *= size.x / size.y;
    float dist = length(toCenter);
    float angle = atan2(toCenter.y, toCenter.x);

    // Expanding ring that thins as it grows, so it reads as energy leaving
    // rather than as a growing disc.
    float radius = progress * 0.62;
    float thickness = 0.14 * (1.0 - progress * 0.72);
    float ring = 1.0 - smoothstep(0.0, thickness, abs(dist - radius));

    // Eight soft rays give the burst direction without discrete particles.
    float rays = 0.72 + 0.28 * cos(angle * 8.0);
    float fade = 1.0 - smoothstep(0.55, 1.0, progress);

    float energy = ring * rays * fade;
    half3 lit = currentColor.rgb + half3(tint) * half(energy * 0.55);
    return half4(min(lit, half3(1.0)), currentColor.a);
}

// contextLens: a bounded, one-shot refraction on the control/background plane
// when context is handed into capture or Eva. Maximum displacement is under
// eight points and the envelope returns the final frame to its original pixels.
[[ stitchable ]] float2 LifeBoardContextLens(
    float2 position,
    float2 size,
    float2 center,
    float progress
) {
    if (size.x <= 0.0 || size.y <= 0.0 || progress <= 0.001 || progress >= 0.999) {
        return position;
    }

    float2 uv = position / size;
    float2 delta = uv - center;
    delta.x *= size.x / size.y;
    float distance = length(delta);
    float2 direction = normalize(delta + 1e-5);
    float envelope = sin(clamp(progress, 0.0, 1.0) * M_PI_F);
    float ringCenter = 0.05 + progress * 0.52;
    float ring = 1.0 - smoothstep(0.0, 0.16, abs(distance - ringCenter));
    float softCore = 1.0 - smoothstep(0.0, 0.42, distance);
    float displacement = min(8.0, (ring * 6.5 + softCore * 1.5) * envelope);
    return position + direction * displacement;
}

// chartRevealSweep: a series drawing itself in. A soft leading edge travels
// left-to-right once; everything behind it is fully opaque, everything ahead is
// clear. This is a mask pass — it never tints or distorts the chart, so values
// stay readable the whole way through and the final frame is pixel-identical
// to the undrawn chart.
[[ stitchable ]] half4 LifeBoardChartRevealSweep(
    float2 position,
    half4 currentColor,
    float2 size,
    float progress,
    float featherWidth
) {
    if (size.x <= 0.0 || progress >= 0.999) {
        return currentColor;
    }
    if (progress <= 0.001) {
        return half4(0.0);
    }

    float x = position.x / size.x;
    // The sweep starts a feather-width off-screen so the first column is
    // already fully revealed when progress reaches 1.
    float feather = clamp(featherWidth, 0.01, 0.5);
    float edge = progress * (1.0 + feather);
    float visibility = 1.0 - smoothstep(edge - feather, edge, x);
    return currentColor * half(visibility);
}

// triageSettle: a short directional ember beneath the Inbox card deck after a
// decision lands. It paints only a narrow travelling streak, then returns to a
// transparent, static plane. Direction is +1 for file/review and -1 for skip.
[[ stitchable ]] half4 LifeBoardTriageSettle(
    float2 position,
    half4 currentColor,
    float2 size,
    float progress,
    float direction,
    float3 tint
) {
    if (size.x <= 0.0 || size.y <= 0.0 || progress <= 0.001 || progress >= 0.999) {
        return currentColor;
    }

    float2 uv = position / size;
    float travel = direction >= 0.0 ? progress : 1.0 - progress;
    float distance = abs(uv.x - travel);
    float streak = 1.0 - smoothstep(0.0, 0.22, distance);
    float vertical = 1.0 - smoothstep(0.05, 0.72, abs(uv.y - 0.52));
    float envelope = sin(progress * M_PI_F);
    float texture = 0.82 + 0.18 * LifeBoardSignature::hash21(floor(position * 0.28));
    float energy = streak * vertical * envelope * texture;
    half alpha = max(currentColor.a, half(energy * 0.26));
    half3 lit = currentColor.rgb + half3(tint) * half(energy * 0.52);
    return half4(min(lit, half3(1.0)), alpha);
}

// taskLandingCaustic: one quiet ring of warm light underneath the day canvas
// after a task's placement has persisted. It never displaces geometry or
// touches the readable row; progress 0 and 1 are exact identity frames.
[[ stitchable ]] half4 LifeBoardTaskLandingCaustic(
    float2 position,
    half4 currentColor,
    float2 size,
    float2 center,
    float progress,
    float3 tint
) {
    if (size.x <= 0.0 || size.y <= 0.0 || progress <= 0.001 || progress >= 0.999) {
        return currentColor;
    }

    float2 uv = position / size;
    float2 delta = uv - center;
    delta.x *= size.x / size.y;
    float distance = length(delta);
    float front = progress * 0.52;
    float ring = 1.0 - smoothstep(0.018, 0.085, abs(distance - front));
    float innerGlow = (1.0 - smoothstep(0.0, max(front, 0.001), distance)) * 0.16;
    float envelope = sin(progress * M_PI_F);
    float texture = 0.90 + LifeBoardSignature::hash21(floor(position * 0.24)) * 0.10;
    float energy = min(1.0, (ring + innerGlow) * envelope * texture);

    half3 lit = currentColor.rgb + half3(tint) * half(energy * 0.28);
    half alpha = max(currentColor.a, half(energy * 0.18));
    return half4(min(lit, half3(1.0)), alpha);
}

// liquidGlassRefract: the selected dock/composer well bending the content
// beneath it. A shallow lens centred on the well, falling off to zero well
// inside its own bounds so neighbouring targets never smear. Displacement is
// capped at six points; this runs only while the selection is moving.
[[ stitchable ]] float2 LifeBoardLiquidGlassRefract(
    float2 position,
    float2 size,
    float2 center,
    float radius,
    float strength
) {
    if (size.x <= 0.0 || size.y <= 0.0 || strength <= 0.001) {
        return position;
    }

    float2 uv = position / size;
    float2 delta = uv - center;
    delta.x *= size.x / size.y;
    float distance = length(delta);
    float safeRadius = max(radius, 1e-4);
    if (distance >= safeRadius) {
        return position;
    }

    // Spherical falloff: strongest just inside the rim, zero at the centre and
    // zero at the edge, which is what makes it read as glass rather than a blur.
    float normalized = distance / safeRadius;
    float lens = sin(normalized * M_PI_F);
    float2 direction = normalize(delta + 1e-5);
    float displacement = min(6.0, lens * strength * 6.0);
    return position - direction * displacement;
}

// cardMorphWarp: the background plane easing out of the way while a card zooms
// into its detail route. Deliberately not applied to the card itself — text and
// charts must stay undistorted. Peaks mid-transition and returns to identity.
[[ stitchable ]] float2 LifeBoardCardMorphWarp(
    float2 position,
    float2 size,
    float2 origin,
    float progress
) {
    if (size.x <= 0.0 || size.y <= 0.0 || progress <= 0.001 || progress >= 0.999) {
        return position;
    }

    float2 uv = position / size;
    float2 delta = uv - origin;
    delta.x *= size.x / size.y;
    float distance = length(delta);
    float envelope = sin(clamp(progress, 0.0, 1.0) * M_PI_F);
    // Push outward near the origin, relaxing to nothing by half the diagonal.
    float falloff = 1.0 - smoothstep(0.0, 0.62, distance);
    float2 direction = normalize(delta + 1e-5);
    float displacement = min(8.0, falloff * envelope * 8.0);
    return position + direction * displacement;
}

// paperGrain: a static, warm tooth over the canvas so large flat areas read as
// pressed paper rather than flat fill. No time input — this must never animate.
[[ stitchable ]] half4 LifeBoardPaperGrain(
    float2 position,
    half4 currentColor,
    float2 size,
    float intensity
) {
    if (size.x <= 0.0 || intensity <= 0.001 || currentColor.a <= 0.001) {
        return currentColor;
    }

    // Two octaves at different scales avoid a visible repeating cell.
    float coarse = LifeBoardSignature::hash21(floor(position * 0.5));
    float fine = LifeBoardSignature::hash21(floor(position * 1.7) + 19.19);
    float grain = (coarse * 0.6 + fine * 0.4) - 0.5;

    // Scale by luminance so shadowed areas do not turn muddy.
    float luma = dot(float3(currentColor.rgb), float3(0.2126, 0.7152, 0.0722));
    float weight = smoothstep(0.08, 0.92, luma);
    half shift = half(grain * intensity * weight * 0.06);
    return half4(clamp(currentColor.rgb + shift, half3(0.0), half3(1.0)), currentColor.a);
}

// ambientDrift: the ambient tier. Unlike every other kernel in this file this
// one has no settled state and no `progress` — it is driven by wall time and
// runs continuously while its host surface is on screen.
//
// It is bound by the DESIGN.md ambient budget: the luminance swing is a couple
// of percent, the spatial frequency is very low, and there is no hue shift, so
// text composited above it never changes contrast enough to matter. Two
// incommensurate periods keep the field from visibly looping.
//
// `intensity` scales the whole effect (caller passes 0 to settle it out).
[[ stitchable ]] half4 LifeBoardAmbientDrift(
    float2 position,
    half4 currentColor,
    float2 size,
    float time,
    float intensity
) {
    if (size.x <= 0.0 || intensity <= 0.001 || currentColor.a <= 0.001) {
        return currentColor;
    }

    float2 uv = position / max(size, float2(1.0));

    // Two slow, low-frequency waves crossing at an angle. Periods 7.3s and
    // 11.9s share no small common multiple, so the pattern does not repeat on
    // any timescale a person will sit and watch.
    float waveA = sin((uv.x * 1.7 + uv.y * 0.9) * M_PI_F + time / 7.3 * M_PI_F * 2.0);
    float waveB = cos((uv.x * -0.8 + uv.y * 1.4) * M_PI_F + time / 11.9 * M_PI_F * 2.0);
    float field = (waveA * 0.6 + waveB * 0.4);

    // Hold the effect off the extremes of the tonal range: blown highlights and
    // crushed shadows are where a 2% shift becomes visible banding.
    float luma = dot(float3(currentColor.rgb), float3(0.2126, 0.7152, 0.0722));
    float weight = smoothstep(0.06, 0.30, luma) * (1.0 - smoothstep(0.86, 0.99, luma));

    half shift = half(field * intensity * weight * 0.022);
    return half4(clamp(currentColor.rgb + shift, half3(0.0), half3(1.0)), currentColor.a);
}

// dissolveAway: a finished row leaving. Pixels erode along a noise threshold
// from the trailing edge, which reads as the item being absorbed rather than
// simply fading. One-shot; the caller removes the view when progress reaches 1.
[[ stitchable ]] half4 LifeBoardDissolveAway(
    float2 position,
    half4 currentColor,
    float2 size,
    float progress,
    float3 emberTint
) {
    if (size.x <= 0.0 || progress <= 0.001) {
        return currentColor;
    }
    if (progress >= 0.999) {
        return half4(0.0);
    }

    float2 uv = position / size;
    float noise = LifeBoardSignature::hash21(floor(position * 0.85));
    // Bias the threshold horizontally so the dissolve travels rather than
    // flickering uniformly across the whole row.
    float threshold = progress * 1.35 - uv.x * 0.35;
    float erosion = threshold - noise * 0.42;

    if (erosion >= 0.32) {
        return half4(0.0);
    }

    float alpha = 1.0 - smoothstep(0.0, 0.32, erosion);
    // A narrow warm rim rides the dissolving boundary.
    float rim = 1.0 - smoothstep(0.0, 0.12, abs(erosion - 0.20));
    half3 lit = currentColor.rgb + half3(emberTint) * half(rim * 0.5);
    return half4(min(lit, half3(1.0)), currentColor.a) * half(alpha);
}

// firstLight: the morning commit landing. A single warm band sweeps once across
// the committed proposal, left to right, brightening what it passes and leaving
// it settled.
//
// Deliberately not daypartBloom: that is a root-atmosphere effect bound to a
// daypart *change*, and committing to a day does not change the hour. This is
// the only signature moment the morning act has — the evening has the ring
// morph, the cross-dissolve and the burst; the morning had nothing at all.
//
// One-shot and fully bounded: at progress 0 and 1 it returns the source colour
// untouched, so a settled day carries no residue.
[[ stitchable ]] half4 LifeBoardFirstLight(
    float2 position,
    half4 currentColor,
    float2 size,
    float progress,
    float3 lightTint
) {
    if (size.x <= 0.0 || progress <= 0.001 || progress >= 0.999) {
        return currentColor;
    }
    if (currentColor.a <= 0.001) {
        return currentColor;
    }

    float2 uv = position / size;

    // The band starts just off the leading edge and exits past the trailing one,
    // so the sweep enters and leaves cleanly rather than popping into view.
    float head = progress * 1.4 - 0.2;

    // A slight downward lean makes the light read as coming from outside the
    // card rather than sliding along it.
    float along = uv.x + uv.y * 0.12;
    float distance = along - head;

    // Narrow core with a soft trailing falloff: the leading edge is crisper than
    // the tail, which is what a real light sweep looks like.
    float core = exp(-(distance * distance) / 0.006);
    float tail = distance < 0.0 ? exp(-(distance * distance) / 0.05) * 0.35 : 0.0;
    float intensity = min(core + tail, 1.0);

    // Fade the whole sweep in and out so neither end of the animation snaps.
    float envelope = sin(progress * M_PI_F);
    intensity *= envelope;

    if (intensity <= 0.001) {
        return currentColor;
    }

    half3 tint = half3(lightTint);
    // Screen rather than add, so already-bright paper cannot blow out to white
    // and readable ink underneath keeps its contrast.
    half3 lit = 1.0h - (1.0h - currentColor.rgb) * (1.0h - tint * half(intensity) * 0.55h);

    return half4(mix(currentColor.rgb, lit, half(intensity)), currentColor.a);
}

// valueDrumWarp: the value tape as a physical cylinder. While a finger is on the
// tape, ticks compress toward the two rims and foreshorten vertically, the way
// the face of a rotating drum does. Identity at the centre detent — the value
// actually being chosen is never distorted — and identity everywhere once the
// finger lifts.
//
// There is no time input. Amplitude is `grip`, which is the gesture's own state,
// so unlike every other travelling effect here this shader is structurally
// incapable of becoming an idle loop.
[[ stitchable ]] float2 LifeBoardValueDrumWarp(
    float2 position,
    float2 size,
    float grip,
    float center
) {
    if (size.x <= 0.0 || size.y <= 0.0 || grip <= 0.001) {
        return position;
    }

    float g = clamp(grip, 0.0, 1.0);
    float anchor = clamp(center, 0.0, 1.0);
    float u = position.x / size.x;
    float v = position.y / size.y;
    float offset = u - anchor;

    // Barrel: sample progressively further out approaching the rims, which reads
    // as compression toward the edges. Exactly identity at offset == 0, so the
    // centre detent and its label stay pixel-accurate.
    float barrel = 1.0 - 0.55 * g * offset * offset;
    float warpedU = anchor + offset * barrel;

    // Cylinder: the rims of a drum face sit further from the eye, so rows there
    // pull toward the horizontal midline. Small — a hint, not a lens.
    float foreshorten = 1.0 - 0.14 * g * clamp(offset * offset * 4.0, 0.0, 1.0);
    float warpedV = 0.5 + (v - 0.5) * foreshorten;

    float2 warped = float2(warpedU * size.x, warpedV * size.y);
    // Hard cap, so a wide tape can never smear a neighbouring control.
    float2 delta = clamp(warped - position, float2(-10.0), float2(10.0));
    return position + delta;
}

// rootTravelShear: the arriving root settling into place after a dock change.
//
// The most-repeated transition in the app, and the only one in DESIGN.md's
// motion grammar with no effect of its own — the shell moved the arriving root
// with a plain offset + opacity, so "travel" carried no spatial information at
// all beyond direction.
//
// A directional shear whose magnitude falls off with distance from the departing
// dock slot, so the side of the screen you launched from lags fractionally
// behind the side you are heading toward. That asymmetry is the whole idea: it
// says *where the content came from*, which a uniform slide cannot.
//
// `origin` is the departing slot's x-centre in unit space, `direction` is -1 or
// +1, `progress` runs 0 -> 1 and the effect is identity at 1. Bounded to a few
// points; this must never be legible as distortion on text.
[[ stitchable ]] float2 LifeBoardRootTravelShear(
    float2 position,
    float2 size,
    float origin,
    float direction,
    float progress
) {
    if (size.x <= 0.0 || size.y <= 0.0 || progress >= 0.999) {
        return position;
    }

    float u = position.x / size.x;
    float v = position.y / size.y;

    // Ease out: most of the shear is spent in the first third of the travel, so
    // the surface reads as settling rather than as arriving bent.
    float remaining = 1.0 - progress;
    float eased = remaining * remaining;

    // Falloff from the origin slot. Content near where the finger was moves
    // least; the far edge leads.
    float distanceFromOrigin = clamp(abs(u - origin), 0.0, 1.0);
    float lead = smoothstep(0.0, 1.0, distanceFromOrigin);

    // Vertical component only. A horizontal shear on a horizontally travelling
    // surface just reads as extra velocity; shearing across the direction of
    // travel is what makes the motion legible as one sheet flexing.
    float shear = direction * lead * eased * 9.0;

    // Slight vertical falloff so the top and bottom edges — where the header and
    // dock sit — stay closer to true than the middle of the reading field.
    float verticalWeight = 1.0 - 0.35 * abs(v - 0.5) * 2.0;

    float2 delta = float2(0.0, shear * verticalWeight);
    return position + clamp(delta, float2(-12.0), float2(12.0));
}
