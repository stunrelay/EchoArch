#version 450

#pragma parameter gamma "Dot Gamma" 2.4 0.0 5.0 0.05
#pragma parameter shine "Dot Shine" 0.05 0.0 0.5 0.01
#pragma parameter blend "Dot Blend" 0.65 0.0 1.0 0.01
#pragma parameter soft "Dot Soft" 0.0 0.0 1.0 0.1

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float gamma;
    float shine;
    float blend;
    float soft;
} params;

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
} global;

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

float dist(vec2 coord, vec2 source) {
    vec2 delta = coord - source;
    return sqrt(dot(delta, delta));
}

float color_bloom(vec3 color) {
    const vec3 gray_coeff = vec3(0.30, 0.59, 0.11);
    float bright = dot(color, gray_coeff);
    return mix(1.0 + params.shine, 1.0 - params.shine, bright);
}

vec3 lookup(vec2 pixel_no, vec2 offset, vec3 color) {
    float delta = dist(fract(pixel_no), offset + vec2(0.5, 0.5));
    return color * exp(-params.gamma * delta * color_bloom(color));
}

vec2 omega = vec2(3.141592654) * vec2(2.0) * params.OriginalSize.xy;
const vec3 offsets = vec3(3.141592654) * vec3(1.0 / 2.0, 1.0 / 2.0 - 2.0 / 3.0, 1.0 / 2.0 - 4.0 / 3.0);

void main() {
    vec2 fragCoord = vTexCoord * params.OutputSize.xy;

    float targetAspect = 4.0 / 3.0;
    float screenAspect = params.OutputSize.x / params.OutputSize.y;
    bool isWide = screenAspect > 1.0;

    float sideThickness   = isWide ? 20.0 : 10.0;
    float topThickness    = isWide ? 10.0 : 20.0;
    float bottomThickness = isWide ? 10.0 : 20.0;

    float cornerRadius = 30.0;
    float bezelCornerRadius = 130.0;
    float margin = 8.0;

    float contentWidth;
    float contentHeight;

    if (screenAspect >= targetAspect) {
        contentHeight = params.OutputSize.y - (topThickness + bottomThickness + 2.0 * margin);
        contentWidth = contentHeight * targetAspect;
    } else {
        contentWidth = params.OutputSize.x - (2.0 * sideThickness + 2.0 * margin);
        contentHeight = contentWidth / targetAspect;
    }

    bool isLandscape = screenAspect >= 1.0;
    float topMargin = isLandscape
        ? (params.OutputSize.y - contentHeight) * 0.5
        : params.OutputSize.y * 0.07;

    vec2 anchorTopCenter = vec2(params.OutputSize.x * 0.5, topMargin + contentHeight);

    vec2 minContent = anchorTopCenter - vec2(contentWidth * 0.5, contentHeight);
    vec2 maxContent = anchorTopCenter + vec2(contentWidth * 0.5, 0.0);

    vec2 minFrame = vec2(minContent.x - sideThickness, minContent.y - topThickness);
    vec2 maxFrame = vec2(maxContent.x + sideThickness, maxContent.y + bottomThickness);

        bool inContent = fragCoord.x >= minContent.x && fragCoord.x <= maxContent.x &&
                     fragCoord.y >= minContent.y && fragCoord.y <= maxContent.y;

    bool inFrame = fragCoord.x >= minFrame.x && fragCoord.x <= maxFrame.x &&
                   fragCoord.y >= minFrame.y && fragCoord.y <= maxFrame.y;

    bool roundedOut = false;
    vec2 frameCornerDist = min(fragCoord - minFrame, maxFrame - fragCoord);
    if (frameCornerDist.x < cornerRadius && frameCornerDist.y < cornerRadius) {
        float dx = cornerRadius - frameCornerDist.x;
        float dy = cornerRadius - frameCornerDist.y;
        if (dx * dx + dy * dy > cornerRadius * cornerRadius) {
            roundedOut = true;
        }
    }

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


    float shadowIntensity = 0.0;
    float distLeft = fragCoord.x;
    float distRight = params.OutputSize.x - fragCoord.x;
    float distTop = fragCoord.y;
    float distBottom = params.OutputSize.y - fragCoord.y;
    float outerShadowWidth = 48.0;

    shadowIntensity += smoothstep(outerShadowWidth, 0.0, distLeft);
    shadowIntensity += smoothstep(outerShadowWidth, 0.0, distRight);
    shadowIntensity += smoothstep(outerShadowWidth, 0.0, distTop);
    shadowIntensity += smoothstep(outerShadowWidth, 0.0, distBottom);
    shadowIntensity = clamp(shadowIntensity * 0.25, 0.0, 0.25);

    float grain = (rand(fragCoord / 4.0) - 0.5) * 0.015;

if (inContent) {
    vec2 contentSize = maxContent - minContent;
    contentSize = max(contentSize, vec2(1.0)); // Prevent divide-by-zero
    vec2 scaledUV = (fragCoord - minContent) / contentSize;

    vec3 color = texture(Source, scaledUV).rgb;
    FragColor = vec4(color, 1.0);
    return;
}
    else if (inFrame && !roundedOut) {
        FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // PORTRAIT MODE ELEMENTS
    if (!isLandscape) {
       


//GREY BORDER

// --------------------
// Bottom grey border with groove texture + dual reflection rays + thin black inline edge
// --------------------
{
    float bottomRectLeft = minFrame.x;
    float bottomRectRight = maxFrame.x;
    float bottomRectWidth = bottomRectRight - bottomRectLeft;
    float bottomRectCenterX = (bottomRectLeft + bottomRectRight) * 0.5;

    float bottomRectY = maxFrame.y - 40.0;
    float bottomRectHeight = 70.0;
    float bottomBorderWidth = 1.0;

    vec3 bottomBaseColor = vec3(0.33);  // slightly lighter gray
    vec3 bottomBorderColor = vec3(0.2);
    vec3 silverReflection = vec3(0.55);
    vec3 blackEdgeColor = vec3(0.0);

    vec2 bottomCenter = vec2(bottomRectCenterX, bottomRectY + bottomRectHeight * 0.5);
    vec2 pos = fragCoord - bottomCenter;
    vec2 halfSize = vec2(bottomRectWidth * 0.5, bottomRectHeight * 0.5);
    vec2 localPos = pos + halfSize;

    if (abs(pos.x) <= halfSize.x && abs(pos.y) <= halfSize.y) {
        // Groove texture
        float stripeSpacing = 7.0;
        float bendFactor = 0.00015;
        float curvature = bendFactor * pow(localPos.x - bottomRectWidth / 2.0, 2.0);
        float stripe = sin((localPos.y + curvature) * 2.0 * 3.14159 / stripeSpacing);
        float stripeShading = smoothstep(-0.2, 0.2, stripe);
        float grooveIntensity = 0.15;

        float shadeY = smoothstep(0.0, bottomRectHeight, localPos.y);
        float verticalLight = mix(0.22, 0.28, shadeY);

        vec3 shadedGray = vec3(verticalLight);
        shadedGray *= 1.0 - grooveIntensity * stripeShading;

        // === Primary reflection rays
        float rayWidth = 8.0;
        float rayFadeRange = 25.0;
        float horizontalShiftAmount = 300.0;
        float shiftedX = localPos.x - horizontalShiftAmount;

        for (int i = 0; i < 3; ++i) {
            float offset = float(i) * 14.0;
            float ray = (shiftedX + localPos.y) - offset;
            float fade = smoothstep(rayWidth, rayWidth + rayFadeRange, abs(ray));

            if (localPos.x < bottomRectWidth * 0.4) {
                float alpha = 1.0 - fade;
                shadedGray = mix(shadedGray, silverReflection, alpha * 0.6);
            }
        }

        // === Secondary reflection rays (smaller offset, farther left)
        float shiftedX2 = localPos.x - (horizontalShiftAmount + 90.0);
        for (int i = 0; i < 2; ++i) {
            float offset = float(i) * 10.0;
            float ray = (shiftedX2 + localPos.y) - offset;
            float fade = smoothstep(rayWidth, rayWidth + rayFadeRange, abs(ray));

            if (localPos.x < bottomRectWidth * 0.3) {
                float alpha = 1.0 - fade;
                shadedGray = mix(shadedGray, silverReflection, alpha * 0.3);
            }
        }

        // Border blend (1px inside)
        if (abs(pos.x) > halfSize.x - bottomBorderWidth || abs(pos.y) > halfSize.y - bottomBorderWidth) {
            shadedGray = mix(bottomBorderColor, shadedGray, 0.5);
        }

        // Thin black inline edge (~1px)
        float edgeWidth = 4.0;
        bool nearEdge = abs(pos.x) > halfSize.x - edgeWidth || abs(pos.y) > halfSize.y - edgeWidth;
        if (nearEdge) {
            shadedGray = mix(blackEdgeColor, shadedGray, 0.3);
        }

        FragColor = vec4(shadedGray, 1.0);
        return;
    }
}

// --------------------
// Top grey border with groove texture + dual reflection rays + thin black inline edge
// --------------------
{
    float topRectLeft = minFrame.x;
    float topRectRight = maxFrame.x;
    float topRectWidth = topRectRight - topRectLeft;
    float topRectCenterX = (topRectLeft + topRectRight) * 0.5;

    float topRectY = minFrame.y + 40.0;
    float topRectHeight = 70.0;
    float topBorderWidth = 1.0;

    vec3 topBaseColor = vec3(0.33);  // slightly lighter gray
    vec3 topBorderColor = vec3(0.2);
    vec3 silverReflection = vec3(0.55);
    vec3 blackEdgeColor = vec3(0.0);

    vec2 topCenter = vec2(topRectCenterX, topRectY - topRectHeight * 0.5);
    vec2 pos = fragCoord - topCenter;
    vec2 halfSize = vec2(topRectWidth * 0.5, topRectHeight * 0.5);
    vec2 localPos = pos + halfSize;

    if (abs(pos.x) <= halfSize.x && abs(pos.y) <= halfSize.y) {
        // Groove texture
        float stripeSpacing = 7.0;
        float bendFactor = 0.00015;
        float curvature = bendFactor * pow(localPos.x - topRectWidth / 2.0, 2.0);
        float stripe = sin((localPos.y + curvature) * 2.0 * 3.14159 / stripeSpacing);
        float stripeShading = smoothstep(-0.2, 0.2, stripe);
        float grooveIntensity = 0.15;

        float shadeY = smoothstep(0.0, topRectHeight, localPos.y);
        float verticalLight = mix(0.28, 0.34, shadeY);

        vec3 shadedGray = vec3(verticalLight);
        shadedGray *= 1.0 - grooveIntensity * stripeShading;

        // === Primary reflection rays
        float rayWidth = 8.0;
        float rayFadeRange = 25.0;
        float horizontalShiftAmount = -300.0;
        float shiftedX = localPos.x - horizontalShiftAmount;

        for (int i = 0; i < 3; ++i) {
            float offset = float(i) * 14.0;
            float ray = (shiftedX - (topRectWidth - localPos.y)) - offset;
            float fade = smoothstep(rayWidth, rayWidth + rayFadeRange, abs(ray));

            if (localPos.x > topRectWidth * 0.6) {
                float alpha = 1.0 - fade;
                shadedGray = mix(shadedGray, silverReflection, alpha * 0.6);
            }
        }

        // === Secondary reflection rays (smaller offset, farther right)
        float shiftedX2 = localPos.x - (horizontalShiftAmount + 90.0);
        for (int i = 0; i < 2; ++i) {
            float offset = float(i) * 10.0;
            float ray = (shiftedX2 - (topRectWidth - localPos.y)) - offset;
            float fade = smoothstep(rayWidth, rayWidth + rayFadeRange, abs(ray));

            if (localPos.x > topRectWidth * 0.7) {
                float alpha = 1.0 - fade;
                shadedGray = mix(shadedGray, silverReflection, alpha * 0.3);
            }
        }

        // Border blend (1px inside)
        if (abs(pos.x) > halfSize.x - topBorderWidth || abs(pos.y) > halfSize.y - topBorderWidth) {
            shadedGray = mix(topBorderColor, shadedGray, 0.5);
        }

        // Thin black inline edge (~1px)
        float edgeWidth = 4.0;
        bool nearEdge = abs(pos.x) > halfSize.x - edgeWidth || abs(pos.y) > halfSize.y - edgeWidth;
        if (nearEdge) {
            shadedGray = mix(blackEdgeColor, shadedGray, 0.3);
        }

        FragColor = vec4(shadedGray, 1.0);
        return;
    }
}

// === Large Thin Black Circle Outline Protruding Top and Bottom + Horizontal line at bottom edge ===
{
    vec2 screenCenter = vec2(params.OutputSize.x * 0.5, (minFrame.y + maxFrame.y) * 0.5);

    float umdRadius = 600.0;
    float ringWidth = 8.0;
    float lineThickness = 6.0;

    float distToCenter = length(fragCoord - screenCenter);

    // Draw circle ring line
    if (abs(distToCenter - umdRadius) <= ringWidth * 0.5) {
        FragColor = vec4(vec3(0.0), 1.0);
        return;
    }

    // Draw horizontal line aligned with bottom edge of circle
    float bottomEdgeY = screenCenter.y + umdRadius;

    if (fragCoord.y > bottomEdgeY - lineThickness * 0.5 &&
        fragCoord.y < bottomEdgeY + lineThickness * 0.5) {
        FragColor = vec4(vec3(0.0), 1.0);
        return;
    }
}

        float grooveThickness = 6.0;

float topBezelTop = 35.0;                // top limit as before
vec2 screenCenter = vec2(params.OutputSize.x * 0.5, (minFrame.y + maxFrame.y) * 0.5);
float umdRadius = 600.0;                 // same radius as circle
float bottomEdgeY = screenCenter.y + umdRadius;  // Y of horizontal line

// Move vertical grooves closer to center
float insetFromSide = 400.0;
float grooveLeftX = params.OutputSize.x * 0.5 - insetFromSide;
float grooveRightX = params.OutputSize.x * 0.5 + insetFromSide;

// Left vertical groove line
if (fragCoord.x > grooveLeftX - grooveThickness * 0.5 &&
    fragCoord.x < grooveLeftX + grooveThickness * 0.5 &&
    fragCoord.y >= topBezelTop && fragCoord.y <= bottomEdgeY) {
    FragColor = vec4(0.0, 0.0, 0.0, 1.0);
    return;
}

// Right vertical groove line
if (fragCoord.x > grooveRightX - grooveThickness * 0.5 &&
    fragCoord.x < grooveRightX + grooveThickness * 0.5 &&
    fragCoord.y >= topBezelTop && fragCoord.y <= bottomEdgeY) {
    FragColor = vec4(0.0, 0.0, 0.0, 1.0);
    return;
}
// --- Extended groove lines into grey bezel (angled inward) ---
{
    float extGrooveThicknessMax = 8.0;
    float extGrooveThicknessMin = 4.0;
    float extInsetFromSide = 400.0;
    float extTaperAmount = 60.0;

    float screenCenterX = params.OutputSize.x * 0.5;
    float baseLeftX = screenCenterX - extInsetFromSide;
    float baseRightX = screenCenterX + extInsetFromSide;

    float extendedTop = 0.0;
    float grooveTop = 35.0;

    if (fragCoord.y >= extendedTop && fragCoord.y <= grooveTop) {
        float yFraction = (fragCoord.y - extendedTop) / (grooveTop - extendedTop);

        // === Center inward groove lines ===
        float grooveLeftX = mix(baseLeftX, baseLeftX + extTaperAmount, 1.0 - yFraction);
        float grooveRightX = mix(baseRightX, baseRightX - extTaperAmount, 1.0 - yFraction);
        float grooveThickness = mix(extGrooveThicknessMin, extGrooveThicknessMax, yFraction);

        if (abs(fragCoord.x - grooveLeftX) < grooveThickness * 0.5 ||
            abs(fragCoord.x - grooveRightX) < grooveThickness * 0.5) {
            FragColor = vec4(0.0, 0.0, 0.0, 1.0);
            return;
        }

        // === Far-corner silver reflection bands ===
        float cornerInset = 180.0;              // much farther out
        float cornerTaperAmount = 80.0;        // steeper angle
        float cornerThicknessMax = 35.0;
        float cornerThicknessMin = 15.0;

        float leftCornerBase = screenCenterX - cornerInset - extInsetFromSide;
        float rightCornerBase = screenCenterX + cornerInset + extInsetFromSide;

        float cornerLeftX = mix(leftCornerBase, leftCornerBase + cornerTaperAmount, 1.0 - yFraction);
        float cornerRightX = mix(rightCornerBase, rightCornerBase - cornerTaperAmount, 1.0 - yFraction);
        float cornerThickness = mix(cornerThicknessMin, cornerThicknessMax, yFraction);

        // Simulate silver metallic gradient (light gray to dark gray)
        vec3 silverTop = vec3(0.32);
        vec3 silverBottom = vec3(0.3);
        vec3 silverColor = mix(silverTop, silverBottom, yFraction);  // vertical gradient

        if (abs(fragCoord.x - cornerLeftX) < cornerThickness * 0.5 ||
            abs(fragCoord.x - cornerRightX) < cornerThickness * 0.5) {
            FragColor = vec4(silverColor, 1.0);
            return;
        }
    }
}

        // CURVED LINE
        {
            float cornerRadiusTop = 70.0;
            float lineThickness = 4.0;
            float topY = 35.0;

            float width = params.OutputSize.x;
            float x = fragCoord.x;
            float y = fragCoord.y;

            float curveY = topY;

            if (x < cornerRadiusTop) {
                float dx = cornerRadiusTop - x;
                float dy = sqrt(cornerRadiusTop * cornerRadiusTop - dx * dx);
                curveY = topY + (cornerRadiusTop - dy);
            } else if (x > width - cornerRadiusTop) {
                float dx = x - (width - cornerRadiusTop);
                float dy = sqrt(cornerRadiusTop * cornerRadiusTop - dx * dx);
                curveY = topY + (cornerRadiusTop - dy);
            }

            // Fill dark gray above curve with 3D shading
            if (y < curveY) {
                float shadeY = smoothstep(0.0, curveY, y);
                float verticalLight = mix(0.22, 0.28, shadeY);

                float vignette = smoothstep(0.0, 0.2, x / width) * smoothstep(0.0, 0.2, (width - x) / width);
                float vignetteDarken = mix(0.0, 0.03, vignette);

                // === Base gray lighting
                vec3 shadedGray = vec3(verticalLight - vignetteDarken);

                // === Add perspective-curved plastic lines === //
                float stripeSpacing = 7.0;
                float bendFactor = 0.00015; // small bend distortion
                float curvature = bendFactor * pow(x - width / 2.0, 2.0); // Parabolic curvature

                float stripe = sin((y + curvature) * 2.0 * 3.14159 / stripeSpacing);

                // Convert sinusoidal stripe into shaded ridges (light/dark bands)
                float stripeShading = smoothstep(-0.2, 0.2, stripe); // soft edges
                float grooveIntensity = 0.15; // how strong the grooves are

                // Apply groove modulation to base color
                shadedGray *= 1.0 - grooveIntensity * stripeShading;

                // 🔹 Highlight strip just below the curve
                float highlightBand = smoothstep(curveY - 2.0, curveY, y);
                shadedGray += vec3(0.08 * (1.0 - highlightBand)); // fade out downwards

                // 🔸 Inner shadow under the edge
                float shadowBand = smoothstep(curveY, curveY + 12.0, y);
                shadedGray *= mix(1.0, 0.92, shadowBand); // dim just below the edge

                FragColor = vec4(shadedGray, 1.0);
                return;
            }

            // Draw black curve line
            if (abs(y - curveY) < lineThickness) {
                FragColor = vec4(0.0, 0.0, 0.0, 1.0);
                return;
            }
        }
    }


// --------------------
// Left and Right grey borders (landscape only) with groove texture + reflection + inline edge
// --------------------
if (isLandscape) {
    // === Common values
    float sideRectTop = minFrame.y;
    float sideRectBottom = maxFrame.y;
    float sideRectHeight = sideRectBottom - sideRectTop;
    float sideRectCenterY = (sideRectTop + sideRectBottom) * 0.5;

    float sideRectWidth = 70.0;
    float sideBorderWidth = 1.0;

    vec3 sideBaseColor = vec3(0.33);
    vec3 sideBorderColor = vec3(0.2);
    vec3 silverReflection = vec3(0.55);
    vec3 blackEdgeColor = vec3(0.0);

    float stripeSpacing = 7.0;
    float bendFactor = 0.00015;
    float grooveIntensity = 0.15;

    float rayWidth = 8.0;
    float rayFadeRange = 25.0;
    float verticalShiftAmount = 300.0;

    // === Left side
    {
        float leftRectX = minFrame.x + 40.0;
        vec2 center = vec2(leftRectX - sideRectWidth * 0.5, sideRectCenterY);
        vec2 pos = fragCoord - center;
        vec2 halfSize = vec2(sideRectWidth * 0.5, sideRectHeight * 0.5);
        vec2 localPos = pos + halfSize;

        if (abs(pos.x) <= halfSize.x && abs(pos.y) <= halfSize.y) {
            float curvature = bendFactor * pow(localPos.y - sideRectHeight / 2.0, 2.0);
            float stripe = sin((localPos.x + curvature) * 2.0 * 3.14159 / stripeSpacing);
            float stripeShading = smoothstep(-0.2, 0.2, stripe);
            float shadeX = smoothstep(0.0, sideRectWidth, localPos.x);
            float horizLight = mix(0.22, 0.28, shadeX);

            vec3 shadedGray = vec3(horizLight);
            shadedGray *= 1.0 - grooveIntensity * stripeShading;

            float baseY = sideRectHeight;  // bottom of the local rectangle
float shiftedY = baseY - localPos.y - 120.0;  // Start from bottom, shift upward slightly

for (int i = 0; i < 3; ++i) {
    float offset = float(i) * 14.0;
    float ray = (shiftedY - localPos.x) - offset;
    float fade = smoothstep(rayWidth, rayWidth + rayFadeRange, abs(ray));

    if (localPos.y > sideRectHeight * 0.6) {  // bottom portion
        float alpha = 1.0 - fade;
        shadedGray = mix(shadedGray, silverReflection, alpha * 0.6);
    }
}

            float shiftedY2 = baseY - localPos.y - 220.0;  // slightly higher

for (int i = 0; i < 2; ++i) {
    float offset = float(i) * 10.0;
    float ray = (shiftedY2 - localPos.x) - offset;
    float fade = smoothstep(rayWidth, rayWidth + rayFadeRange, abs(ray));

    if (localPos.y > sideRectHeight * 0.7) {
        float alpha = 1.0 - fade;
        shadedGray = mix(shadedGray, silverReflection, alpha * 0.3);
    }
}

            if (abs(pos.x) > halfSize.x - sideBorderWidth || abs(pos.y) > halfSize.y - sideBorderWidth) {
                shadedGray = mix(sideBorderColor, shadedGray, 0.5);
            }

            float edgeWidth = 4.0;
            bool nearEdge = abs(pos.x) > halfSize.x - edgeWidth || abs(pos.y) > halfSize.y - edgeWidth;
            if (nearEdge) {
                shadedGray = mix(blackEdgeColor, shadedGray, 0.3);
            }

            FragColor = vec4(shadedGray, 1.0);
            return;
        }
    }

    // === Right side
    {
        float rightRectX = maxFrame.x - 40.0;
        vec2 center = vec2(rightRectX + sideRectWidth * 0.5, sideRectCenterY);
        vec2 pos = fragCoord - center;
        vec2 halfSize = vec2(sideRectWidth * 0.5, sideRectHeight * 0.5);
        vec2 localPos = pos + halfSize;

        if (abs(pos.x) <= halfSize.x && abs(pos.y) <= halfSize.y) {
            float curvature = bendFactor * pow(localPos.y - sideRectHeight / 2.0, 2.0);
            float stripe = sin((localPos.x + curvature) * 2.0 * 3.14159 / stripeSpacing);
            float stripeShading = smoothstep(-0.2, 0.2, stripe);
            float shadeX = smoothstep(0.0, sideRectWidth, localPos.x);
            float horizLight = mix(0.28, 0.34, shadeX);

            vec3 shadedGray = vec3(horizLight);
            shadedGray *= 1.0 - grooveIntensity * stripeShading;

            float shiftedY = localPos.y - verticalShiftAmount;

for (int i = 0; i < 3; ++i) {
    float offset = float(i) * 14.0;
    float ray = (shiftedY - (sideRectWidth - localPos.x)) - offset;
    float fade = smoothstep(rayWidth, rayWidth + rayFadeRange, abs(ray));

    if (localPos.y < sideRectHeight * 0.4) {  // Upper half
        float alpha = 1.0 - fade;
        shadedGray = mix(shadedGray, silverReflection, alpha * 0.6);
    }
}

            float shiftedY2 = localPos.y - 220.0;  // Instead of verticalShiftAmount + 90

for (int i = 0; i < 2; ++i) {
    float offset = float(i) * 10.0;
    float ray = (shiftedY2 - (sideRectWidth - localPos.x)) - offset;
    float fade = smoothstep(rayWidth, rayWidth + rayFadeRange, abs(ray));

    if (localPos.y < sideRectHeight * 0.3) {
        float alpha = 1.0 - fade;
        shadedGray = mix(shadedGray, silverReflection, alpha * 0.3);
    }
}

            if (abs(pos.x) > halfSize.x - sideBorderWidth || abs(pos.y) > halfSize.y - sideBorderWidth) {
                shadedGray = mix(sideBorderColor, shadedGray, 0.5);
            }

            float edgeWidth = 4.0;
            bool nearEdge = abs(pos.x) > halfSize.x - edgeWidth || abs(pos.y) > halfSize.y - edgeWidth;
            if (nearEdge) {
                shadedGray = mix(blackEdgeColor, shadedGray, 0.3);
            }

            FragColor = vec4(shadedGray, 1.0);
            return;
        }
    }
}




    // Fallback yellow bezel base color + grain + shadow
    vec3 baseColor = vec3(0.898, 0.831, 0.753);
    baseColor += grain;
    baseColor *= 1.0 - shadowIntensity;
    FragColor = vec4(baseColor, 1.0);
}


