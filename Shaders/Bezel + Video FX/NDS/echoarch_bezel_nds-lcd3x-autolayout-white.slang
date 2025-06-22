#version 450

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float brighten_scanlines;
    float brighten_lcd;
} params;

#pragma parameter brighten_scanlines "Brighten Scanlines" 16.0 1.0 32.0 0.5
#define brighten_scanlines params.brighten_scanlines
#pragma parameter brighten_lcd "Brighten LCD" 4.0 1.0 12.0 0.1
#define brighten_lcd params.brighten_lcd

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
} global;

vec2 omega = vec2(3.141592654) * vec2(2.0) * params.OriginalSize.xy;
const vec3 offsets = vec3(3.141592654) * vec3(1.0 / 2.0, 1.0 / 2.0 - 2.0 / 3.0, 1.0 / 2.0 - 4.0 / 3.0);

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 fragCoord = vTexCoord * params.OutputSize.xy;

    float screenAspect = params.OutputSize.x / params.OutputSize.y;
    bool isPortrait = screenAspect < 1.0;

    // Frame thickness
    float sideThickness   = isPortrait ? 20.0 : 30.0;
    float topThickness    = isPortrait ? 30.0 : 20.0;
    float bottomThickness = topThickness;
    float cornerRadius = 30.0;
    float bezelCornerRadius = 60.0;
    float margin = 8.0;

    // Target NDS aspect ratio: two 4:3 screens stacked (portrait) or side-by-side (landscape)
    float screenAspectRatio = 4.0 / 3.0;
    float targetAspect = isPortrait ? screenAspectRatio / 2.0 : screenAspectRatio * 2.0;

    float contentWidth;
    float contentHeight;

    if (screenAspect >= targetAspect) {
        contentHeight = params.OutputSize.y - (topThickness + bottomThickness + 2.0 * margin);
        contentWidth = contentHeight * targetAspect;
    } else {
        contentWidth = params.OutputSize.x - (2.0 * sideThickness + 2.0 * margin);
        contentHeight = contentWidth / targetAspect;
    }

    float topMargin = (params.OutputSize.y - contentHeight) * (isPortrait ? 0.06 : 0.5);
    vec2 anchorTopCenter = vec2(params.OutputSize.x * 0.5, topMargin + contentHeight);

    vec2 minContent = anchorTopCenter - vec2(contentWidth * 0.5, contentHeight);
    vec2 maxContent = anchorTopCenter + vec2(contentWidth * 0.5, 0.0);

    vec2 minFrame = vec2(minContent.x - sideThickness, minContent.y - topThickness);
    vec2 maxFrame = vec2(maxContent.x + sideThickness, maxContent.y + bottomThickness);

    bool inContent = fragCoord.x >= minContent.x && fragCoord.x <= maxContent.x &&
                     fragCoord.y >= minContent.y && fragCoord.y <= maxContent.y;

    bool inFrame = fragCoord.x >= minFrame.x && fragCoord.x <= maxFrame.x &&
                   fragCoord.y >= minFrame.y && fragCoord.y <= maxFrame.y;

    // Rounded black frame corners
    bool roundedOut = false;
    vec2 frameCornerDist = min(fragCoord - minFrame, maxFrame - fragCoord);
    if (frameCornerDist.x < cornerRadius && frameCornerDist.y < cornerRadius) {
        float dx = cornerRadius - frameCornerDist.x;
        float dy = cornerRadius - frameCornerDist.y;
        if (dx * dx + dy * dy > cornerRadius * cornerRadius) {
            roundedOut = true;
        }
    }

    // Rounded outer bezel corners
    vec2 screenMin = vec2(0.0);
    vec2 screenMax = params.OutputSize.xy;
    vec2 bezelCornerDist = min(fragCoord - screenMin, screenMax - fragCoord);
    if (bezelCornerDist.x < bezelCornerRadius && bezelCornerDist.y < bezelCornerRadius) {
        float dx = bezelCornerRadius - bezelCornerDist.x;
        float dy = bezelCornerRadius - bezelCornerDist.y;
        if (dx * dx + dy * dy > bezelCornerRadius * bezelCornerRadius) {
            discard;
        }
    }

// --- Rounded inline border around the whole screen edge ---
{
    float edgeThickness = 1.7;
    float radius = bezelCornerRadius;
    vec3 edgeColor = vec3(0.2);  // grey

    vec2 screenMin = vec2(0.0);
    vec2 screenMax = params.OutputSize.xy;
    vec2 bezelCornerDist = min(fragCoord - screenMin, screenMax - fragCoord);

    float dx = radius - bezelCornerDist.x;
    float dy = radius - bezelCornerDist.y;
    float dist = sqrt(dx * dx + dy * dy);

    // Outside radius: invisible
    if (bezelCornerDist.x < radius && bezelCornerDist.y < radius) {
        if (abs(dist - radius) < edgeThickness) {
            FragColor = vec4(edgeColor, 1.0);
            return;
        }
    } else {
        // Flat edge sections
        float minEdgeDist = min(min(fragCoord.x, params.OutputSize.x - fragCoord.x),
                                min(fragCoord.y, params.OutputSize.y - fragCoord.y));
        if (minEdgeDist < edgeThickness) {
            FragColor = vec4(edgeColor, 1.0);
            return;
        }
    }
}


    // Outer bezel shadow
    float shadowIntensity = 0.0;
    float outerShadowWidth = 48.0;
    shadowIntensity += smoothstep(outerShadowWidth, 0.0, fragCoord.x);
    shadowIntensity += smoothstep(outerShadowWidth, 0.0, params.OutputSize.x - fragCoord.x);
    shadowIntensity += smoothstep(outerShadowWidth, 0.0, fragCoord.y);
    shadowIntensity += smoothstep(outerShadowWidth, 0.0, params.OutputSize.y - fragCoord.y);
    shadowIntensity = clamp(shadowIntensity * 0.25, 0.0, 0.25);

    // Subtle grain
    float grain = (rand(fragCoord / 4.0) - 0.5) * 0.015;

    if (inContent) {
        vec2 scaledUV = (fragCoord - minContent) / (maxContent - minContent);
        vec2 videoUV;

        if (isPortrait) {
            float gap = 20.0 / contentHeight; // 16px visual gap, normalized to 0–1 in content space

    float halfGap = gap * 0.5;

    if (scaledUV.y < 0.5 - halfGap) {
        // Top screen
        float y = scaledUV.y / (0.5 - halfGap);
        videoUV = vec2(scaledUV.x, y * 0.5);
    } else if (scaledUV.y > 0.5 + halfGap) {
        // Bottom screen
        float y = (scaledUV.y - 0.5 - halfGap) / (0.5 - halfGap);
        videoUV = vec2(scaledUV.x, y * 0.5 + 0.5);
    } else {
        // In the gap between top and bottom screens
        FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }
}
        


else {
    float gap = 16.0 / contentWidth; // 16px gap
    float halfGap = gap * 0.5;

    if (scaledUV.x < 0.5 - halfGap) {
        // Left screen = top DS screen
        float x = scaledUV.x / (0.5 - halfGap); // normalized 0–1 range
        videoUV = vec2(x, scaledUV.y * 0.5); // no extra scaling needed
    }
    else if (scaledUV.x > 0.5 + halfGap) {
        // Right screen = bottom DS screen
        float x = (scaledUV.x - 0.5 - halfGap) / (0.5 - halfGap);
        videoUV = vec2(x, scaledUV.y * 0.5 + 0.5);
    }
    else {
        // Vertical black gap
        FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }
}







        // LCD effect
        vec3 res = texture(Source, videoUV).xyz;
        vec2 angle = videoUV * omega;
        float yfactor = (brighten_scanlines + sin(angle.y)) / (brighten_scanlines + 1);
        vec3 xfactors = (brighten_lcd + sin(angle.x + offsets)) / (brighten_lcd + 1);
        vec3 color = yfactor * xfactors * res;

        FragColor = vec4(color, 1.0);
    } else if (inFrame && !roundedOut) {
        FragColor = vec4(0.0, 0.0, 0.0, 1.0); // Black frame
    } else {
        // Bezel color with grain and shadow (#f5f5f5 approx linear)
        vec3 baseColor = vec3(0.96);
        baseColor += grain;
        baseColor *= 1.0 - shadowIntensity;
        FragColor = vec4(baseColor, 1.0);
    }
}