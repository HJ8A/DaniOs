// Astronomía sin internet para los widgets (relojes 2 y 3).
//
//  sunElevation(date, lat, lon)  → altura del sol sobre el horizonte, en grados
//  sunTimes(date, lat, lon)      → { sunrise, sunset, noon } (Date) del día local de `date`, o null (sol de medianoche/noche polar)
//  moon(date)                    → { age (días), illumination (0..1), waxing (bool), phase (nombre) }
//
// Sol: algoritmo de la NOAA (Solar Calculator), precisión de ~1 minuto.
// Luna: mes sinódico medio desde una luna nueva de referencia; suficiente
// para dibujar la fase (error de horas, no de días).
.pragma library

const RAD = Math.PI / 180

function julianDay(date) {
    return date.getTime() / 86400000 + 2440587.5
}

// Declinación del sol (grados) y ecuación del tiempo (minutos).
function solar(jd) {
    const T     = (jd - 2451545) / 36525
    const L0    = ((280.46646 + T * (36000.76983 + T * 0.0003032)) % 360 + 360) % 360
    const M     = 357.52911 + T * (35999.05029 - 0.0001537 * T)
    const e     = 0.016708634 - T * (0.000042037 + 0.0000001267 * T)
    const C     = Math.sin(M * RAD) * (1.914602 - T * (0.004817 + 0.000014 * T))
                + Math.sin(2 * M * RAD) * (0.019993 - 0.000101 * T)
                + Math.sin(3 * M * RAD) * 0.000289
    const omega = 125.04 - 1934.136 * T
    const lam   = L0 + C - 0.00569 - 0.00478 * Math.sin(omega * RAD)
    const eps0  = 23 + (26 + (21.448 - T * (46.815 + T * (0.00059 - T * 0.001813))) / 60) / 60
    const eps   = eps0 + 0.00256 * Math.cos(omega * RAD)
    const decl  = Math.asin(Math.sin(eps * RAD) * Math.sin(lam * RAD)) / RAD
    const y     = Math.pow(Math.tan(eps * RAD / 2), 2)
    const eqTime = 4 / RAD * (y * Math.sin(2 * L0 * RAD) - 2 * e * Math.sin(M * RAD)
                 + 4 * e * y * Math.sin(M * RAD) * Math.cos(2 * L0 * RAD)
                 - 0.5 * y * y * Math.sin(4 * L0 * RAD) - 1.25 * e * e * Math.sin(2 * M * RAD))
    return { decl: decl, eqTime: eqTime }
}

function sunElevation(date, lat, lon) {
    const s      = solar(julianDay(date))
    const utcMin = date.getUTCHours() * 60 + date.getUTCMinutes() + date.getUTCSeconds() / 60
    let tst = (utcMin + s.eqTime + 4 * lon) % 1440
    if (tst < 0)
        tst += 1440
    const ha    = tst / 4 - 180
    const cosZ  = Math.sin(lat * RAD) * Math.sin(s.decl * RAD) + Math.cos(lat * RAD) * Math.cos(s.decl * RAD) * Math.cos(ha * RAD)
    const zenith = Math.acos(Math.max(-1, Math.min(1, cosZ))) / RAD
    return 90 - zenith
}

function sunTimes(date, lat, lon) {
    const d = new Date(date)
    d.setHours(12, 0, 0, 0)
    const s = solar(julianDay(d))
    const cosHa = Math.cos(90.833 * RAD) / (Math.cos(lat * RAD) * Math.cos(s.decl * RAD)) - Math.tan(lat * RAD) * Math.tan(s.decl * RAD)
    if (cosHa > 1 || cosHa < -1)
        return null
    const ha      = Math.acos(cosHa) / RAD
    const noonUtc = 720 - 4 * lon - s.eqTime                 // minutos UTC
    const dayUtc  = Date.UTC(d.getFullYear(), d.getMonth(), d.getDate())
    const at = minutes => new Date(dayUtc + minutes * 60000)
    return { sunrise: at(noonUtc - 4 * ha), sunset: at(noonUtc + 4 * ha), noon: at(noonUtc) }
}

const SYNODIC = 29.530588853
const NEW_MOON_JD = 2451550.1 // luna nueva del 6 de enero de 2000, 18:14 UTC

const PHASES = [
    [1.84566,  "Luna nueva"],
    [5.53699,  "Luna creciente"],
    [9.22831,  "Cuarto creciente"],
    [12.91963, "Gibosa creciente"],
    [16.61096, "Luna llena"],
    [20.30228, "Gibosa menguante"],
    [23.99361, "Cuarto menguante"],
    [27.68493, "Luna menguante"],
    [SYNODIC,  "Luna nueva"],
]

function moon(date) {
    let age = (julianDay(date) - NEW_MOON_JD) % SYNODIC
    if (age < 0)
        age += SYNODIC
    const illumination = (1 - Math.cos(2 * Math.PI * age / SYNODIC)) / 2
    let phase = "Luna nueva"
    for (let i = 0; i < PHASES.length; ++i)
        if (age < PHASES[i][0]) {
            phase = PHASES[i][1]
            break
        }
    return { age: age, illumination: illumination, waxing: age < SYNODIC / 2, phase: phase }
}

// ── Posiciones sobre la Tierra (reloj 3) ─────────────────────────────────────

// Punto subsolar: donde el sol está justo encima (grados).
function subsolarPoint(date) {
    const s = solar(julianDay(date))
    const utcMin = date.getUTCHours() * 60 + date.getUTCMinutes() + date.getUTCSeconds() / 60
    let lon = (720 - utcMin - s.eqTime) / 4
    lon = ((lon + 540) % 360) - 180
    return { lat: s.decl, lon: lon }
}

// Punto sublunar: donde la luna está justo encima (grados). Teoría de baja
// precisión (términos principales), error de ~1°: suficiente para un icono.
function sublunarPoint(date) {
    const jd = julianDay(date)
    const T  = (jd - 2451545) / 36525
    const Lp = 218.316 + 481267.881 * T          // longitud media
    const M  = 134.963 + 477198.867 * T          // anomalía media
    const F  = 93.272 + 483202.018 * T           // argumento de latitud
    const lam  = (Lp + 6.289 * Math.sin(M * RAD)) * RAD
    const beta = (5.128 * Math.sin(F * RAD)) * RAD
    const eps  = 23.4397 * RAD
    const ra   = Math.atan2(Math.sin(lam) * Math.cos(eps) - Math.tan(beta) * Math.sin(eps), Math.cos(lam))
    const dec  = Math.asin(Math.sin(beta) * Math.cos(eps) + Math.cos(beta) * Math.sin(eps) * Math.sin(lam))
    const gmst = (280.46061837 + 360.98564736629 * (jd - 2451545)) % 360
    let lon = ra / RAD - gmst
    lon = (((lon + 180) % 360) + 360) % 360 - 180
    return { lat: dec / RAD, lon: lon }
}

// Vector unitario (marco fijo a la Tierra: x → lon 0°, y → lon 90°E, z → norte).
function toVector(latDeg, lonDeg) {
    const la = latDeg * RAD, lo = lonDeg * RAD
    return { x: Math.cos(la) * Math.cos(lo), y: Math.cos(la) * Math.sin(lo), z: Math.sin(la) }
}

// Proyección ortográfica de un punto (lat, lon) sobre un globo centrado en
// (centerLat, centerLon): x a la derecha, y hacia arriba, z > 0 si está de frente.
function project(latDeg, lonDeg, centerLatDeg, centerLonDeg) {
    const P = toVector(latDeg, lonDeg)
    const sLa = Math.sin(centerLatDeg * RAD), cLa = Math.cos(centerLatDeg * RAD)
    const sLo = Math.sin(centerLonDeg * RAD), cLo = Math.cos(centerLonDeg * RAD)
    return {
        x: -sLo * P.x + cLo * P.y,
        y: -sLa * cLo * P.x - sLa * sLo * P.y + cLa * P.z,
        z: cLa * cLo * P.x + cLa * sLo * P.y + sLa * P.z
    }
}
