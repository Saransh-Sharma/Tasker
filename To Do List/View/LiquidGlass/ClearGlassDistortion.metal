#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>

using namespace metal;

[[ stitchable ]]
float2 clearGlassDistortion(
    float2 position,
    float2 center,
    float2 size,
    float thickness,
    float refractiveIndex,
    float displayScale
) {
    float2 safeSize = max(size, float2(1.0));
    float safeIndex = max(refractiveIndex, 1.0001);
    float safeDisplayScale = max(displayScale, 0.001);

    float2 centered = (position - center) / safeSize;
    float radiusSquared = dot(centered, centered);

    if (radiusSquared > 0.25) {
        return position;
    }

    float z = sqrt(max(0.0, 0.25 - radiusSquared));
    float3 normal = normalize(float3(centered, z));
    float distortionStrength = 1.0 - (1.0 / safeIndex);
    float2 offset = normal.xy * distortionStrength * (thickness / safeDisplayScale);

    return position + offset;
}
