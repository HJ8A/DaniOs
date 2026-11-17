// Visualizador de audio en la GPU (barras, onda o puntos; abajo, espejo o
// alrededor de un rectángulo redondeado). La CPU solo pasa los valores.
// Compilar con:  qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o spectrum.frag.qsb spectrum.frag
//
//   v0..v15     hasta 64 valores 0..1 (4 por vec4)
//   area        tamaño del item en px
//   modeId      0 abajo · 1 espejo (arriba y abajo) · 2 contorno · 3 solo arriba
//   kind        0 barras · 1 onda · 2 puntos
//   shapeRect   contorno (modo 2): semiancho, semialto, radio (px, centrado)
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    vec4 v0; vec4 v1; vec4 v2; vec4 v3; vec4 v4; vec4 v5; vec4 v6; vec4 v7;
    vec4 v8; vec4 v9; vec4 v10; vec4 v11; vec4 v12; vec4 v13; vec4 v14; vec4 v15;
    vec4  colorA;
    vec4  colorB;
    vec4  shapeRect;
    vec2  area;
    float count;
    float modeId;
    float kind;
    float thickness;
    float roundedF;
    float symmetric;
    float reach;
    float gap;
    float maxBarWidth;
};

const float PI = 3.14159265358979;

float rawVal(int i) {
    vec4 vs[16] = vec4[16](v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15);
    return vs[i >> 2][i & 3];
}

float val(int i, bool wrap) {
    int n = int(count);
    i = wrap ? ((i % n) + n) % n : clamp(i, 0, n - 1);
    return rawVal(i);
}

// Catmull-Rom entre centros de barra (t en unidades de barra)
float smoothVal(float t, bool wrap) {
    float x = t - 0.5;
    int i = int(floor(x));
    float f = x - float(i);
    float p0 = val(i - 1, wrap), p1 = val(i, wrap), p2 = val(i + 1, wrap), p3 = val(i + 2, wrap);
    float r = 0.5 * (2.0 * p1 + (-p0 + p2) * f + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f * f
                     + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * f * f * f);
    return clamp(r, 0.0, 1.0);
}

// Contorno: degradado a lo largo (simétrico en estéreo). Bordes de la
// pantalla: degradado vertical, de la base (A) a la punta (B).
vec4 colorAt(float t, float e) {
    float c;
    if (modeId > 1.5 && modeId < 2.5) {
        c = clamp(t / count, 0.0, 1.0);
        if (symmetric > 0.5)
            c = abs(c - 0.5) * 2.0;
    } else {
        c = clamp(e / max(reach, 1.0), 0.0, 1.0);
    }
    return mix(colorA, colorB, c);
}

// t: posición en barras · along: px a lo largo, desde el centro de la barra
// slot: px por barra · e: px desde la base hacia fuera
vec4 shade(float t, float along, float slot, float e, bool wrap) {
    float bw = max(1.5, min(maxBarWidth, slot * thickness));
    vec4 col = colorAt(t, e);
    float a = 0.0;

    if (kind < 0.5) {                                  // barras
        float v = val(int(floor(t)), wrap);
        float h = max(roundedF > 0.5 ? bw : bw * 0.5, v * reach);
        float sdf;
        if (roundedF > 0.5) {
            // En los bordes de la pantalla la base queda fuera (solo la punta es
            // redonda); en el contorno la barra es una cápsula.
            float lower = (modeId > 1.5 && modeId < 2.5) ? bw * 0.5 : -bw * 0.5;
            float yc = clamp(e, lower, max(lower, h - bw * 0.5));
            sdf = length(vec2(along, e - yc)) - bw * 0.5;
        } else {
            sdf = max(abs(along) - bw * 0.5, max(-e, e - h));
        }
        a = clamp(0.5 - sdf, 0.0, 1.0);
    } else if (kind < 1.5) {                           // onda
        float h = smoothVal(t, wrap) * reach;
        float g = e - h;
        float grad = max(length(vec2(dFdx(g), dFdy(g))), 1e-3);
        float line = clamp(max(1.5, bw * 0.35) * 0.5 - abs(g) / grad + 0.5, 0.0, 1.0);
        float fill = (e >= 0.0 && e < h) ? mix(0.55, 0.15, clamp(e / max(reach, 1.0), 0.0, 1.0)) : 0.0;
        a = max(line, fill);
    } else {                                           // puntos
        float v = val(int(floor(t)), wrap);
        float r = max(2.0, bw * 0.8) * 0.5;
        float cy = r + v * max(0.0, reach - 2.0 * r);
        a = clamp(0.5 - (length(vec2(along, e - cy)) - r), 0.0, 1.0) * (0.35 + 0.65 * v);
    }
    return vec4(col.rgb, 1.0) * col.a * a;
}

void main() {
    vec2 px = qt_TexCoord0 * area;
    vec4 outc = vec4(0.0);

    if (modeId < 1.5 || modeId > 2.5) {
        float slot = area.x / count;
        float t = px.x / slot;
        float along = (fract(t) - 0.5) * slot;
        outc = shade(t, along, slot, modeId > 2.5 ? px.y : area.y - px.y, false);
        if (modeId > 0.5 && modeId < 1.5) {
            vec4 top = shade(t, along, slot, px.y, false);
            outc = outc + top * (1.0 - outc.a);
        }
    } else {
        // Contorno: distancia con signo al rectángulo redondeado y posición
        // a lo largo del perímetro (desde abajo al centro, por la izquierda).
        vec2 p = px - area * 0.5;
        vec2 b = shapeRect.xy;
        float r = min(shapeRect.z, min(b.x, b.y));
        vec2 q = abs(p) - (b - r);
        float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
        if (d < 0.0) {
            fragColor = vec4(0.0);
            return;
        }
        float hx = b.x - r, hy = b.y - r;
        float Lh = 2.0 * hx, Lv = 2.0 * hy, arc = 0.5 * PI * r;
        float L = 2.0 * Lh + 2.0 * Lv + 4.0 * arc;
        float s;
        if (q.x > 0.0 && q.y > 0.0) {                  // esquinas
            if (p.x < 0.0 && p.y > 0.0) {
                vec2 w = p - vec2(-hx, hy);
                s = 0.5 * Lh + atan(-w.x, w.y) * r;
            } else if (p.x < 0.0) {
                vec2 w = p - vec2(-hx, -hy);
                s = 0.5 * Lh + arc + Lv + atan(-w.y, -w.x) * r;
            } else if (p.y < 0.0) {
                vec2 w = p - vec2(hx, -hy);
                s = 0.5 * Lh + 2.0 * arc + Lv + Lh + atan(w.x, -w.y) * r;
            } else {
                vec2 w = p - vec2(hx, hy);
                s = 0.5 * Lh + 3.0 * arc + 2.0 * Lv + Lh + atan(w.y, w.x) * r;
            }
        } else if (q.x > q.y) {                        // lados verticales
            s = p.x < 0.0 ? 0.5 * Lh + arc + (hy - p.y)
                          : 0.5 * Lh + 3.0 * arc + Lv + Lh + (p.y + hy);
        } else if (p.y > 0.0) {                        // abajo
            s = p.x <= 0.0 ? -p.x : L - p.x;
        } else {                                       // arriba
            s = 0.5 * Lh + 2.0 * arc + Lv + (p.x + hx);
        }
        float slot = L / count;
        float t = s / slot;
        float along = (fract(t) - 0.5) * slot;
        outc = shade(t, along, slot, d - gap, true);
    }
    fragColor = outc * qt_Opacity;
}
