// Disco de vinilo (sin la etiqueta central, que es la portada encima).
// Surcos concéntricos, zona lisa junto a la etiqueta, borde, y dos reflejos
// de luz opuestos que NO giran con el disco (como en uno real): por eso este
// shader es estático y solo la etiqueta rota.
// Compilar con:  qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o vinyl.frag.qsb vinyl.frag
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    vec4  tint;          // color del acento (reflejo sutil)
    float labelFrac;     // radio de la etiqueta / radio del disco
    float pixels;        // radio del disco en px (antialias)
};

void main() {
    vec2 p = qt_TexCoord0 * 2.0 - 1.0;
    float r = length(p);
    float aa = 1.5 / max(pixels, 1.0);

    float disc = 1.0 - smoothstep(1.0 - aa, 1.0, r);
    if (disc <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    // Base casi negra
    vec3 col = vec3(0.045, 0.045, 0.05);

    // Surcos: zona grabada entre la etiqueta (+ salida lisa) y el borde
    float grooveStart = labelFrac + 0.07;
    float grooveEnd = 0.965;
    float inGrooves = smoothstep(grooveStart, grooveStart + 0.01, r) * (1.0 - smoothstep(grooveEnd - 0.01, grooveEnd, r));
    float fine = 0.5 + 0.5 * sin(r * pixels * 1.6);
    float bands = 0.5 + 0.5 * sin(r * 38.0);          // pistas
    col += inGrooves * (0.018 * fine + 0.012 * bands);

    // Reflejos opuestos (fijos) + un toque del acento
    float ang = atan(p.y, p.x);
    float sheen = pow(abs(cos(ang - 0.75)), 14.0);
    col += inGrooves * sheen * (0.22 * vec3(1.0) + 0.10 * tint.rgb) * (0.55 + 0.45 * fine);

    // Borde exterior ligeramente más claro
    float rim = smoothstep(0.975, 0.99, r);
    col += rim * 0.06;

    // Hueco de la etiqueta (la dibuja la portada encima)
    float label = 1.0 - smoothstep(labelFrac - aa, labelFrac, r);
    float a = disc * (1.0 - label);

    fragColor = vec4(col * a, a) * qt_Opacity;
}
