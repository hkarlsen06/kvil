#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Two separable passes vary the blur continuously with vertical position.
[[ stitchable ]] half4 progressiveLandscapeBlur(
    float2 position, SwiftUI::Layer layer, float4 bounds, float startY, float endY,
    float maximumRadius, float2 axis) {
  float radius = maximumRadius * smoothstep(startY, endY, position.y);
  if (radius < 0.01) {
    return layer.sample(position);
  }

  half4 color = half4(0);
  float totalWeight = 0;
  for (int sample = -16; sample <= 16; ++sample) {
    float distance = float(sample) / 16.0;
    float weight = exp(-4.5 * distance * distance);
    // Extend edge pixels rather than sampling transparency beyond the artwork.
    float2 samplePosition = clamp(position + axis * distance * radius,
                                  bounds.xy + 0.5, bounds.xy + bounds.zw - 0.5);
    color += layer.sample(samplePosition) * half(weight);
    totalWeight += weight;
  }
  return color / half(totalWeight);
}
