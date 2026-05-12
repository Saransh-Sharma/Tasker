#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>

using namespace metal;

[[ stitchable ]]
half4 Ripple(
    float2 position,
    SwiftUI::Layer layer,
    float2 origin,
    float time,
    float amplitude,
    float frequency,
    float decay,
    float speed
) {
    const float safeAmplitude = max(amplitude, 0.0001);
    const float safeSpeed = max(speed, 0.0001);

    float2 delta = position - origin;
    float distance = length(delta);
    float delay = distance / safeSpeed;

    time -= delay;
    time = max(0.0, time);

    float rippleAmount = safeAmplitude * sin(frequency * time) * exp(-decay * time);

    // Avoid NaNs when sampling exactly at the ripple origin.
    float2 direction = distance > 0.0001 ? delta / distance : float2(0.0, 0.0);
    float2 displacedPosition = position + rippleAmount * direction;

    half4 color = layer.sample(displacedPosition);
    color.rgb += 0.3 * (rippleAmount / safeAmplitude) * color.a;

    return color;
}
