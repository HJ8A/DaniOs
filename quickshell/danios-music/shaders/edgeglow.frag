// Bordes de luz que reaccionan a la música (DaniOS Music, fase 2).
// Línea de neón a lo largo de un rectángulo redondeado (el borde de la
// ventana) con resplandor hacia dentro, ondulado por el espectro (estéreo:
// izquierda/derecha, graves abajo al centro).
//
// Rendimiento: salida temprana para todo píxel lejos del borde (casi toda la
// ventana); el resto es una distancia con signo y una interpolación.
// Compilar con:  qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o edgeglow.frag.qsb edgeglow.frag
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    vec4 v0; vec4 v1; vec4 v2; vec4 v3; vec4 v4; vec4 v5; vec4 v6; vec4 v7;
    vec4 v8; vec4 v9; vec4 v10; vec4 v11; vec4 v12; vec4 v13; vec4 v14; vec4 v15;
    vec4  colorA;       // acento de la canción
    vec4  colorB;       // variante de tono
    vec2  area;         // tamaño en px
    float count;        // barras (≤ 64)
    float radius;       // radio de las esquinas (px)
    float inset;        // distancia del contorno luminoso al borde (px)
    float reach;        // alcance máximo del resplandor hacia dentro (px)
    float core;         // grosor de la línea de neón (px)
    float phase;        // avanza con cada cuadro de cava
    float energy;       // pulso de graves 0..1
    float intensity;    // brillo general
};

const float PI = 3.14159265358979;

float rawVal(int i) {
    vec4 vs[16] = vec4[16](v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15);
    return vs[i >> 2][i & 3];
}

float val(int i) {
    int n = int(count);
    return rawVal(((i % n) + n) % n);
}

// Catmull-Rom circular entre centros de barra (t en unidades de barra)
float smoothVal(float t) {
    float x = t - 0.5;
    int i = int(floor(x));
    float f = x - float(i);
    float p0 = val(i - 1), p1 = val(i), p2 = val(i + 1), p3 = val(i + 2);
    float r = 0.5 * (2.0 * p1 + (-p0 + p2) * f + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f * f
                     + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * f * f * f);
    return clamp(r, 0.0, 1.0);
}

void main() {
    vec2 px = qt_TexCoord0 * area;
    vec2 p = px - area * 0.5;
    vec2 b = area * 0.5 - inset;
    float r = min(radius, min(b.x, b.y));
    vec2 q = abs(p) - (b - r);
    // d > 0 fuera del contorno (hacia el borde de la ventana), < 0 dentro
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;

    // Cada lado aporta su propio resplandor (distancia a ESE lado y nivel de
    // la música en ESE punto del perímetro) y se combinan como luz. Así las
    // esquinas se funden sin la costura diagonal que aparecía al tomar solo el
    // lado más cercano, y cada aporte se apaga suavemente hasta 0 antes del
    // límite (sin el corte visible de la versión anterior).
    float limit = reach * 2.0;
    float dTop = p.y + b.y, dBottom = b.y - p.y, dLeft = p.x + b.x, dRight = b.x - p.x;
    float dMin = min(min(dTop, dBottom), min(dLeft, dRight));

    // Línea de neón sobre el contorno redondeado (y su halo hacia el borde)
    float line = exp(-abs(d) / max(core, 0.5));

    // Salida temprana: lejos de todos los bordes no hay nada que dibujar
    if (dMin > limit && line < 0.002) {
        fragColor = vec4(0.0);
        return;
    }

    // Perímetro rectangular, 0 arriba al centro y por la izquierda (mitad
    // izquierda = canal izquierdo; graves, en el centro del arreglo estéreo de
    // cava, abajo al centro). Continuo en las 4 esquinas.
    float L = 4.0 * b.x + 4.0 * b.y;
    float sTop = p.x <= 0.0 ? -p.x : L - p.x;
    float sLeft = b.x + (p.y + b.y);
    float sBottom = b.x + 2.0 * b.y + (p.x + b.x);
    float sRight = 3.0 * b.x + 2.0 * b.y + (b.y - p.y);

    float dist[4] = float[4](dTop, dLeft, dBottom, dRight);
    float pos[4] = float[4](sTop, sLeft, sBottom, sRight);

    float keep = 1.0;          // producto de (1 − aporte): mezcla tipo "pantalla"
    float wsum = 0.0;
    vec3 csum = vec3(0.0);
    float hNear = 0.0, dBest = 1e9;
    vec3 cNear = colorA.rgb;

    for (int k = 0; k < 4; ++k) {
        float u = pos[k] / L;
        float h = pow(smoothVal(u * count), 0.8);
        float mixT = 0.5 + 0.5 * sin(u * 2.0 * PI * 2.0 + phase * 0.35);
        vec3 c = mix(colorA.rgb, colorB.rgb, mixT);
        if (dist[k] < dBest) {
            dBest = dist[k];
            hNear = h;
            cNear = c;
        }
        if (dist[k] > limit)
            continue;

        // Onda: entra más donde hay más sonido; una ondulación viaja por el borde
        float ripple = 1.0 + 0.3 * sin(pos[k] * 0.025 - phase * 2.2) * (0.25 + h);
        float extent = (core * 4.0 + h * reach * 1.3) * ripple;
        float inward = max(dist[k], 0.0);
        float wide = exp(-inward / max(extent * 0.55, 1.0));
        float near = exp(-inward / max(extent * 0.18, 1.0));
        float g = (0.55 * wide + 0.6 * near) * (0.22 + 0.78 * h);
        g *= 1.0 - smoothstep(limit * 0.5, limit, inward);          // apagado suave
        g = clamp(g * (0.8 + 0.6 * energy) * intensity, 0.0, 1.0);

        keep *= 1.0 - g;
        wsum += g;
        csum += c * g;
    }

    float glowA = 1.0 - keep;
    vec3 glowC = wsum > 0.0 ? csum / wsum : cNear;

    float lineA = clamp(line * (0.6 + 0.4 * hNear) * intensity, 0.0, 1.0);
    vec3 lineC = mix(cNear, vec3(1.0), 0.45);                        // núcleo casi blanco

    float a = 1.0 - (1.0 - glowA) * (1.0 - lineA);
    vec3 col = a > 0.0 ? (glowC * glowA + lineC * lineA) / max(glowA + lineA, 1e-4) : glowC;

    // Mezcla casi aditiva (alfa menor que el color): suma luz sobre el video
    // en vez de taparlo, como el neón real.
    fragColor = vec4(col * a, a * 0.55) * qt_Opacity;
}
