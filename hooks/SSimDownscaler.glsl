// SSimDownscaler by Shiandow
//
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Lesser General Public
// License as published by the Free Software Foundation; either
// version 3.0 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Lesser General Public License for more details.
// 
// You should have received a copy of the GNU Lesser General Public
// License along with this library.

//!HOOK POSTKERNEL
//!BIND HOOKED
//!BIND PREKERNEL
//!SAVE Var
//!HEIGHT NATIVE_CROPPED.h
//!WHEN NATIVE_CROPPED.w POSTKERNEL.w >
//!DESC SSimDownscaler Variance I

#define factor      ((input_size*POSTKERNEL_pt)[axis])

#define axis 0

#define offset      vec2(0,0)

#define Kernel(x)   cos(acos(-1.0)*x/taps)
#define taps        2.0

vec4 hook() {
    vec2 base = PREKERNEL_pt * (PREKERNEL_pos * input_size + tex_offset);

    // Calculate bounds
    float low  = floor((PREKERNEL_pos - 0.5*taps*POSTKERNEL_pt) * input_size - offset + tex_offset + 0.5)[axis];
    float high = floor((PREKERNEL_pos + 0.5*taps*POSTKERNEL_pt) * input_size - offset + tex_offset + 0.5)[axis];

    float W = 0.0;
    vec4 avg = vec4(0);
    vec2 pos = base;

    for (float k = 0.0; k < high - low; k++) {
        pos[axis] = PREKERNEL_pt[axis] * (k + low + 0.5);
        float rel = (pos[axis] - base[axis])*POSTKERNEL_size[axis] + offset[axis]*factor;
        float w = Kernel(rel);

        avg += w * pow(textureLod(PREKERNEL_raw, pos, 0.0), vec4(2.0));
        W += w;
    }
    avg /= W;

    return avg;
}

//!HOOK POSTKERNEL
//!BIND HOOKED
//!BIND Var
//!SAVE Var
//!WHEN NATIVE_CROPPED.h POSTKERNEL.h >
//!DESC SSimDownscaler Variance II

#define factor      ((Var_size*POSTKERNEL_pt)[axis])

#define axis 1

#define offset      vec2(0,0)

#define Kernel(x)   cos(acos(-1.0)*x/taps)
#define taps        2.0

vec4 hook() {
    // Calculate bounds
    float low  = floor((Var_pos - 0.5*taps*POSTKERNEL_pt) * Var_size - offset + 0.5)[axis];
    float high = floor((Var_pos + 0.5*taps*POSTKERNEL_pt) * Var_size - offset + 0.5)[axis];

    float W = 0.0;
    vec4 avg = vec4(0);
    vec2 pos = Var_pos;

    for (float k = 0.0; k < high - low; k++) {
        pos[axis] = Var_pt[axis] * (k + low + 0.5);
        float rel = (pos[axis] - Var_pos[axis])*POSTKERNEL_size[axis] + offset[axis]*factor;
        float w = Kernel(rel);

        avg += w * textureLod(Var_raw, pos, 0.0);
        W += w;
    }
    avg /= W;

    return clamp(avg, 0.0, 1.0);
}

//!HOOK POSTKERNEL
//!BIND HOOKED
//!SAVE sMean
//!WHEN NATIVE_CROPPED.w POSTKERNEL.w >
//!DESC SSimDownscaler Convolution

#define offset      vec2(0,0)

#define Kernel(x)   pow(0.25, abs(x))
#define taps        3.0
#define maxtaps     taps

vec4 ScaleH(vec2 pos) {
    // Calculate bounds
    float low  = floor(-0.5*maxtaps - offset)[0];
    float high = floor(+0.5*maxtaps - offset)[0];

    float W = 0.0;
    vec4 avg = vec4(0);

    for (float k = 0.0; k < maxtaps; k++) {
        pos[0] = POSTKERNEL_pos[0] + POSTKERNEL_pt[0] * (k + low + 1.0);
        float rel = (k + low + 1.0) + offset[0];
        float w = Kernel(rel);

        avg += w * clamp(textureLod(POSTKERNEL_raw, pos, 0.0), 0.0, 1.0);
        W += w;
    }
    avg /= W;

    return avg;
}

vec4 hook() {
    // Calculate bounds
    float low  = floor(-0.5*maxtaps - offset)[1];
    float high = floor(+0.5*maxtaps - offset)[1];

    float W = 0.0;
    vec4 avg = vec4(0);
    vec2 pos = POSTKERNEL_pos;

    for (float k = 0.0; k < maxtaps; k++) {
        pos[1] = POSTKERNEL_pos[1] + POSTKERNEL_pt[1] * (k + low + 1.0);
        float rel = (k + low + 1.0) + offset[1];
        float w = Kernel(rel);

        avg += w * ScaleH(pos);
        W += w;
    }
    avg /= W;

    return avg;
}

//!HOOK POSTKERNEL
//!BIND HOOKED
//!BIND sMean
//!BIND Var
//!SAVE Var
//!WHEN NATIVE_CROPPED.w POSTKERNEL.w >
//!DESC SSimDownscaler calc R

#define offset      vec2(0,0)

#define Kernel(x)   pow(0.25, abs(x))
#define taps        3.0
#define maxtaps     taps

#define Correction (1.0 - (1.0 + 4.0*pow(Kernel(1.0), 2.0) + 4.0 * pow(Kernel(2.0),2.0)) / pow(1.0 + 4.0*Kernel(1.0) + 4.0*Kernel(2.0), 2.0))

mat2x4 ScaleH(vec2 pos) {
    // Calculate bounds
    float low  = floor(-0.5*maxtaps - offset)[0];
    float high = floor(+0.5*maxtaps - offset)[0];

    float W = 0.0;
    mat2x4 avg = mat2x4(0);

    for (float k = 0.0; k < maxtaps; k++) {
        pos[0] = POSTKERNEL_pos[0] + POSTKERNEL_pt[0] * (k + low + 1.0);
        float rel = (k + low + 1.0) + offset[0];
        float w = Kernel(rel);

        avg += w * mat2x4(pow(clamp(textureLod(POSTKERNEL_raw, pos, 0.0), 0.0, 1.0), vec4(2.0)), textureLod(Var_raw, pos, 0.0));
        W += w;
    }
    avg /= W;

    return avg;
}

vec4 hook() {
    // Calculate bounds
    float low  = floor(-0.5*maxtaps - offset)[1];
    float high = floor(+0.5*maxtaps - offset)[1];

    float W = 0.0;
    mat2x4 avg = mat2x4(0);
    vec2 pos = POSTKERNEL_pos;
    vec4 mean = sMean_texOff(0);

    for (float k = 0.0; k < maxtaps; k++) {
        pos[1] = POSTKERNEL_pos[1] + POSTKERNEL_pt[1] * (k + low + 1.0);
        float rel = (k + low + 1.0) + offset[1];
        float w = Kernel(rel);

        avg += w * ScaleH(pos);
        W += w;
    }
    avg /= W;

    avg[0] = clamp(avg[0] - pow(mean, vec4(2.0)), 0.0, 1.0);
    avg[1] = clamp(avg[1] - pow(mean, vec4(2.0)), 0.0, 1.0);
    return mix(vec4(1.0), 1.0 / sqrt(vec4(1.0) + avg[1] * Correction / avg[0]), lessThan(vec4(0.0), avg[0]));
}

//!HOOK POSTKERNEL
//!BIND HOOKED
//!BIND sMean
//!BIND Var
//!WHEN NATIVE_CROPPED.w POSTKERNEL.w >
//!DESC SSimDownscaler final pass

#define strength    0.4

#define offset      vec2(0,0)

#define Kernel(x)   pow(0.25, abs(x))
#define taps        3.0
#define maxtaps     taps

#define Gamma(x)    ( pow(clamp(x, 0.0, 1.0), vec3(1.0/2.0)) )
#define GammaInv(x) ( pow(clamp(x, 0.0, 1.0), vec3(2.0)) )

vec4 ScaleH(vec2 pos, vec3 L) {
    // Calculate bounds
    float low  = floor(-0.5*maxtaps - offset)[0];
    float high = floor(+0.5*maxtaps - offset)[0];

    float W = 0.0;
    vec4 avg = vec4(0);

    for (float k = 0.0; k < maxtaps; k++) {
        pos[0] = POSTKERNEL_pos[0] + POSTKERNEL_pt[0] * (k + low + 1.0);
        float rel = (k + low + 1.0) + offset[0];
        float w = Kernel(rel);
        vec3 R = 1.0 / textureLod(Var_raw, pos, 0.0).rgb;

        avg += w * vec4(GammaInv(mix(Gamma(textureLod(sMean_raw, pos, 0.0).rgb), L, R)), dot(R, R));
        W += w;
    }
    avg /= W;

    return avg;
}

vec4 hook() {
    vec4 L = POSTKERNEL_texOff(0);

    // Calculate bounds
    float low  = floor(-0.5*maxtaps - offset)[1];
    float high = floor(+0.5*maxtaps - offset)[1];

    float W = 0.0;
    vec4 avg = vec4(0);
    vec2 pos = POSTKERNEL_pos;

    for (float k = 0.0; k < maxtaps; k++) {
        pos[1] = POSTKERNEL_pos[1] + POSTKERNEL_pt[1] * (k + low + 1.0);
        float rel = (k + low + 1.0) + offset[1];
        float w = Kernel(rel);

        avg += w * ScaleH(pos, Gamma(L.rgb));
        W += w;
    }
    avg /= W;

    L.rgb = GammaInv(mix(Gamma(L.rgb), Gamma(avg.rgb), strength / (strength + (1.0 - strength) * avg.a / 200.0)));
    return L;
}
