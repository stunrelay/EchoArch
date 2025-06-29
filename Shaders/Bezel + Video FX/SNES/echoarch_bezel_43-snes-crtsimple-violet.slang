#version 450

/*
 *  CRT-simple shader
 * 
 *  Copyright (C) 2011 DOLLS. Based on cgwg's CRT shader.
 *  Ported and improved by DariusG @2023
 */

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float DISTORTION, SCANLINE, INPUTGAMMA, OUTPUTGAMMA, MASK, SIZE, DOWNSCALE;
} params;

#pragma parameter DISTORTION "Distortion" 0.12 0.0 0.30 0.01
#pragma parameter SCANLINE "Scanline Weight" 0.3 0.2 0.6 0.05
#pragma parameter DOWNSCALE "Scanlines Downscale" 1.0 1.0 2.0 1.0
#pragma parameter INPUTGAMMA "Input Gamma" 2.4 0.0 4.0 0.05
#pragma parameter OUTPUTGAMMA "Output Gamma" 2.2 0.0 4.0 0.05
#pragma parameter MASK "Mask Brightness" 0.7 0.0 1.0 0.05
#pragma parameter SIZE "Mask Size" 1.0 1.0 2.0 1.0

#define outgamma (1.0 / params.OUTPUTGAMMA)
#define scale (params.SourceSize.xy / params.OriginalSize.xy)

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord * 1.0001;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 1) uniform sampler2D Source;

float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 scanlineWeights(float distance, vec4 color) {
    vec4 wid = 2.0 + 2.0 * pow(color, vec4(4.0));
    vec4 weights = vec4(distance / params.SCANLINE);
    return 1.4 * exp(-pow(weights * inversesqrt(0.5 * wid), wid)) / (0.6 + 0.2 * wid);
}

vec2 Distort(vec2 coord) {
    vec2 CURVATURE_DISTORTION = vec2(params.DISTORTION, params.DISTORTION * 1.5);
    vec2 barrelScale = 1.0 - (0.23 * CURVATURE_DISTORTION);
    coord *= params.SourceSize.xy / params.OriginalSize.xy;
    coord -= vec2(0.5);
    float rsq = dot(coord, coord);
    coord += coord * (CURVATURE_DISTORTION * rsq);
    coord *= barrelScale;

    if (abs(coord.x) >= 0.5 || abs(coord.y) >= 0.5)
        return vec2(-1.0);
    else {
        coord += vec2(0.5);
        coord /= params.SourceSize.xy / params.OriginalSize.xy;
        return coord;
    }
}

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
        : params.OutputSize.y * 0.1;

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
    // Rescale fragCoord to a 0–1 coordinate inside the video area
    vec2 screenSize = maxContent - minContent;
    if (screenSize.x <= 0.0 || screenSize.y <= 0.0) discard;

    vec2 screenCoord = (fragCoord - minContent) / screenSize;
    screenCoord = clamp(screenCoord, 0.0, 1.0);

    // Feed corrected coord into CRT shader
    vec2 xy = Distort(screenCoord);
    if (xy.x < 0.0 || xy.y < 0.0) {
        discard;
    }

    vec2 ratio_scale = xy * params.SourceSize.xy - 0.5;
    vec2 uv_ratio = fract(ratio_scale / params.DOWNSCALE);
    xy = (floor(ratio_scale) + 0.5) / params.SourceSize.xy;

    vec4 col1 = texture(Source, xy);
    col1 = pow(col1, vec4(params.INPUTGAMMA));

    vec4 col2 = texture(Source, xy + vec2(0.0, params.SourceSize.w));
    col2 = pow(col2, vec4(params.INPUTGAMMA));

    vec4 w1 = scanlineWeights(uv_ratio.y, col1);
    vec4 w2 = scanlineWeights(1.0 - uv_ratio.y, col2);

    vec3 color = (col1 * w1 + col2 * w2).rgb;

    vec3 dotMaskWeights = mix(vec3(params.MASK), vec3(1.0), fract(fragCoord.x * 0.5 / params.SIZE));
    color *= dotMaskWeights;

    FragColor = vec4(pow(color, vec3(outgamma)), 1.0);
    return;
} else if (inFrame && !roundedOut) {
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


        float verticalGap = 150.0;
float bezelY = maxFrame.y + verticalGap;

vec3 baseColor = vec3(0.31, 0.17, 0.41);       // solid black fill
vec3 borderColor = vec3(0.2);     // subtle darker inline border
vec3 shadowColor = vec3(0.08);    // more subtle shadow
float borderWidth = 1.0;          // thinner inline border

vec2 shadowOffset = vec2(0.0, 4.0); // shadow offset (a bit lighter)

// === Rectangles ===
float rectRadius = 8.0;               // much smaller corner radius
vec2 rectSize = vec2(250.0, 80.0);    // visibly short rectangles

vec2 rect1 = vec2(params.OutputSize.x * 0.22, bezelY);
vec2 rect2 = vec2(params.OutputSize.x * 0.78, bezelY);
vec2 rects[2] = vec2[2](rect1, rect2);

bool insideShape = false;

// Draw rectangles
for (int i = 0; i < 2; i++) {
    vec2 pos = fragCoord - rects[i];
    vec2 d = abs(pos) - rectSize * 0.5;
    float distToEdge = length(max(d, 0.0)) - rectRadius;

    if (distToEdge < 0.0) {
        insideShape = true;
        if (distToEdge > -borderWidth) {
            FragColor = vec4(borderColor, 0.7); // subtle, partially transparent border
        } else {
            FragColor = vec4(baseColor, 1.0);
        }
        return;
    }
}

// === Shadows for rectangles (fainter) ===
for (int i = 0; i < 2; i++) {
    vec2 posShadow = fragCoord - (rects[i] + shadowOffset);
    vec2 dShadow = abs(posShadow) - rectSize * 0.5;
    float distShadow = length(max(dShadow, 0.0)) - rectRadius;

    if (distShadow < 0.0) {
        FragColor = vec4(shadowColor, 0.3); // fainter shadow
        return;
    }
}

// --- Connecting black horizontal line between top edges of the two rectangles ---

float lineThickness = 6.0;  // Thickness of the connecting line

// Compute the Y coordinate of the top edge of the rectangles
float rectTopY = bezelY - rectSize.y * 0.5;

// Left and right X edges of the rectangles (centers +/- half width)
float leftRectRightX = rects[0].x + rectSize.x * 0.5;
float rightRectLeftX = rects[1].x - rectSize.x * 0.5;

// Draw horizontal line only between these two X positions and at rectTopY height
if (fragCoord.y > rectTopY - lineThickness * 0.5 &&
    fragCoord.y < rectTopY + lineThickness * 0.5 &&
    fragCoord.x >= leftRectRightX && 
    fragCoord.x <= rightRectLeftX) {
    FragColor = vec4(0.0, 0.0, 0.0, 1.0); // solid black horizontal line
    return;
}

// === Vertical lines extending from rectangle edges to top groove ===
if (!isLandscape) {
    float grooveY = mix(35.0, minFrame.y, 0.5);  // from existing groove definition
    float lineThickness = 6.0;

    for (int i = 0; i < 2; i++) {
        float leftX  = rects[i].x - rectSize.x * 0.5;
        float rightX = rects[i].x + rectSize.x * 0.5;
        float startY = rects[i].y;

        // Left edge line
        if (fragCoord.x > leftX - lineThickness * 0.5 &&
            fragCoord.x < leftX + lineThickness * 0.5 &&
            fragCoord.y < startY && fragCoord.y > grooveY) {
            FragColor = vec4(0.0, 0.0, 0.0, 1.0);  // solid black
            return;
        }

        // Right edge line
        if (fragCoord.x > rightX - lineThickness * 0.5 &&
            fragCoord.x < rightX + lineThickness * 0.5 &&
            fragCoord.y < startY && fragCoord.y > grooveY) {
            FragColor = vec4(0.0, 0.0, 0.0, 1.0);
            return;
        }
    }
}




        // --- Plastic join grooves in top yellow bezel ---

        float grooveThickness = 8.0;  // Increased from 3.0 to make lines thicker

        float topBezelTop = 35.0;
        float topBezelBottom = minFrame.y;
        float grooveY = mix(topBezelTop, topBezelBottom, 0.5);

        // Move vertical grooves closer to center
        float insetFromSide = 470.0;  // Reduced from 15.0 to bring lines closer inward
        float grooveLeftX = params.OutputSize.x * 0.5 - insetFromSide;
        float grooveRightX = params.OutputSize.x * 0.5 + insetFromSide;

        // Horizontal groove line (unchanged)
        if (fragCoord.y > grooveY - grooveThickness * 0.5 &&
            fragCoord.y < grooveY + grooveThickness * 0.5) {
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
    vec3 baseColor = vec3(0.416, 0.322, 0.639);
    baseColor += grain;
    baseColor *= 1.0 - shadowIntensity;
    FragColor = vec4(baseColor, 1.0);
}


