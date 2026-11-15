// Reloj 3 — globo terráqueo en proyección ortográfica con día y noche reales.
// Compilar con:  qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o earth.frag.qsb earth.frag
//
// Uniforms (mismos nombres que las propiedades del ShaderEffect en ClockEarth.qml):
//   centerLat/centerLon  centro de la vista en radianes (la ciudad + el giro al pasar el mouse)
//   sunDir               vector unitario hacia el sol, marco fijo a la Tierra
//                        (x → lon 0°, y → lon 90°E, z → polo norte)
//   atmosphere           rgb del halo/atmósfera, a = intensidad
//   globeScale           radio del globo como fracción de la mitad del item (deja sitio al halo)
//   nightLights          intensidad de las luces de ciudades
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float centerLat;
    float centerLon;
    vec4  sunDir;
    vec4  atmosphere;
    float globeScale;
    float nightLights;
};

layout(binding = 1) uniform sampler2D dayTex;
layout(binding = 2) uniform sampler2D nightTex;

const float PI = 3.14159265358979;

void main() {
    vec2 p = (qt_TexCoord0 * 2.0 - 1.0) / globeScale;
    p.y = -p.y;                       // y hacia arriba
    float r = length(p);

    // Fuera del disco: halo de atmósfera que se desvanece rápido
    if (r > 1.0) {
        float halo = exp(-(r - 1.0) * 16.0) * atmosphere.a * 0.55;
        fragColor = vec4(atmosphere.rgb * halo, halo) * qt_Opacity;   // premultiplicado
        return;
    }

    float z = sqrt(max(0.0, 1.0 - r * r));
    float sLa = sin(centerLat), cLa = cos(centerLat);
    float sLo = sin(centerLon), cLo = cos(centerLon);
    vec3 east  = vec3(-sLo, cLo, 0.0);
    vec3 north = vec3(-sLa * cLo, -sLa * sLo, cLa);
    vec3 front = vec3(cLa * cLo, cLa * sLo, sLa);
    vec3 P = normalize(p.x * east + p.y * north + z * front);

    float lat = asin(clamp(P.z, -1.0, 1.0));
    float lon = atan(P.y, P.x);
    vec2 uv = vec2((lon + PI) / (2.0 * PI), (0.5 * PI - lat) / PI);

    vec3 day   = texture(dayTex, uv).rgb;
    vec3 night = texture(nightTex, uv).rgb;

    // Luz del sol: d > 0 de día; transición suave en el crepúsculo
    float d   = dot(P, sunDir.xyz);
    float lit = smoothstep(-0.10, 0.12, d);
    vec3 dayShade   = day * (0.30 + 0.70 * clamp(d * 1.4 + 0.25, 0.0, 1.0));
    vec3 nightShade = day * 0.05 + night * nightLights;
    vec3 col = mix(nightShade, dayShade, lit);

    // Borde de atmósfera (más visible del lado iluminado)
    float rim = pow(1.0 - z, 2.5);
    col += atmosphere.rgb * rim * atmosphere.a * (0.35 + 0.65 * lit);

    // Borde suave del disco (antialias)
    float edge = 1.0 - smoothstep(0.985, 1.0, r);
    fragColor = vec4(col * edge, edge) * qt_Opacity;
}
