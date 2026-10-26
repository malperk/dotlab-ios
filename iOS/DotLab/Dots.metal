#include <metal_stdlib>
using namespace metal;

struct DotVertex {
    float4 position [[position]];
    float2 uv;
    float3 color;
};

vertex DotVertex dotVertex(uint vertexID [[vertex_id]], uint instance [[instance_id]],
                           const device float4* dots [[buffer(0)]],
                           constant float2& aspect [[buffer(1)]]) {
    const float2 corners[6] = {float2(-1,-1), float2(1,-1), float2(-1,1),
                               float2(-1,1), float2(1,-1), float2(1,1)};
    float4 dot = dots[instance];
    float2 uv = corners[vertexID];
    float2 position = float2(dot.x * 2 - 1, 1 - dot.y * 2);
    position += uv * dot.z * 2 * aspect;
    float sweep = clamp(dot.x * 0.65 + dot.y * 0.35, 0.0f, 1.0f);
    float3 color = mix(float3(0.22, 0.89, 0.72), float3(0.52, 0.66, 1.0), sweep);
    color = mix(color, float3(1.0, 0.77, 0.43), dot.w);
    return {float4(position, 0, 1), uv, color};
}

fragment float4 dotFragment(DotVertex in [[stage_in]]) {
    float distance = length(in.uv);
    float edge = max(fwidth(distance), 0.02f);
    float alpha = (1 - smoothstep(1 - edge, 1.0f, distance)) * 0.62;
    return float4(in.color, alpha);
}
