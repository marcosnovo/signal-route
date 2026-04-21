#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Holographic foil — iridescent rainbow bands + Fresnel edge glow.
// Lightweight: two sin-wave patterns + edge distance. No per-pixel noise.

[[ stitchable ]]
half4 holographic(float2 position, half4 color, float2 size, float tiltX, float tiltY) {
    float2 uv = position / size;

    // Fresnel edge effect — more shimmer at card edges
    float2 centered = uv - 0.5;
    float fresnel = smoothstep(0.15, 0.50, length(centered));

    // Two diagonal waves at different angles — shift with tilt
    float wave1 = uv.x * 7.0 + uv.y * 4.5 + tiltX * 2.8 + tiltY * 2.0;
    float wave2 = uv.x * 3.5 - uv.y * 6.0 + tiltX * 1.4 - tiltY * 2.5;

    // Spectral decomposition — R, G, B at 120° offsets
    half3 r1 = half3(
        half(0.5 + 0.5 * sin(wave1)),
        half(0.5 + 0.5 * sin(wave1 + 2.094)),
        half(0.5 + 0.5 * sin(wave1 + 4.189))
    );
    half3 r2 = half3(
        half(0.5 + 0.5 * sin(wave2)),
        half(0.5 + 0.5 * sin(wave2 + 2.094)),
        half(0.5 + 0.5 * sin(wave2 + 4.189))
    );

    half3 rainbow = mix(r1, r2, half(0.30));

    // Luminance gate + Fresnel boost
    half lum = dot(color.rgb, half3(0.299, 0.587, 0.114));
    half strength = smoothstep(half(0.05), half(0.40), lum) * half(0.18)
                  + half(fresnel) * half(0.10);

    return half4(color.rgb + rainbow * strength * color.a, color.a);
}
