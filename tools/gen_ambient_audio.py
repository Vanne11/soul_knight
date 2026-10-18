"""Audio de ambiente, antorchas y pasos -> assets/audio/ambient/*.wav
Mono, 16 bits, 22050 Hz (igual que el resto). Todo sintetizado y reproducible
(semillas fijas). Los bucles se construyen con filtros por FFT (periodicos) o con
eventos que dan la vuelta al final: el empalme no tiene clic.
Estilo chiptune suave: tonos triangulares/pulso muy bajos + ruido filtrado,
con una pizca de reduccion de bits para que suene "del juego".
Uso (desde la raiz del proyecto): python3 tools/gen_ambient_audio.py"""
import os
import wave
import numpy as np

SR = 22050
OUT = "assets/audio/ambient/"
os.makedirs(OUT, exist_ok=True)
REPORT = []


def bw(x, lo, hi, order=2):
    """Pasabanda Butterworth (magnitud) por FFT. lo/hi None = sin limite."""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    f[0] = 1e-6
    m = np.ones_like(f)
    if lo:
        m *= 1.0 / (1.0 + (lo / f) ** (2 * order))
    if hi:
        m *= 1.0 / (1.0 + (f / hi) ** (2 * order))
    return np.fft.irfft(X * m, len(x))


def noise(rng, n):
    return rng.standard_normal(n)


def t_(n):
    return np.arange(n) / SR


def bits(x, b=7):
    q = 2 ** (b - 1)
    return np.round(x * q) / q


def norm(x, peak):
    return x * (peak / max(1e-9, np.abs(x).max()))


def fade(x, a=0.003, r=0.01):
    x = x.copy()
    na, nr = max(1, int(a * SR)), max(1, int(r * SR))
    x[:na] *= np.linspace(0, 1, na)
    x[-nr:] *= np.linspace(1, 0, nr)
    return x


def tri(f, n):
    ph = (np.cumsum(np.broadcast_to(f, (n,))) / SR) % 1.0
    return 4 * np.abs(ph - 0.5) - 1


def sine(f, n):
    return np.sin(2 * np.pi * np.cumsum(np.broadcast_to(f, (n,))) / SR)


def save(name, x, loop=False, peak=0.8):
    x = norm(x, peak)
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(OUT + name + ".wav", "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(pcm.tobytes())
    rms = float(np.sqrt((x ** 2).mean()))
    # salto en el empalme comparado con el salto tipico entre muestras
    seam = abs(float(x[0] - x[-1]))
    typ = float(np.abs(np.diff(x)).mean())
    REPORT.append((name, len(x) / SR, float(np.abs(x).max()), rms, seam, typ, loop,
                   float(abs(x[0])), float(abs(x[-1]))))


def echo(x, delay, gain, times, damp=0.55):
    """Ecos que se van apagando y oscureciendo (marmol)."""
    out = np.zeros(len(x) + int(delay * SR * times) + 10)
    out[:len(x)] += x
    cur = x
    for k in range(1, times + 1):
        cur = bw(cur, None, 2600 * damp ** k) * gain
        i = int(delay * SR * k)
        out[i:i + len(cur)] += cur
    return out


# ------------------------------------------------------------------ ambiente puntual
def drip(seed):
    rng = np.random.default_rng(seed)
    n = int(0.45 * SR)
    t = t_(n)
    f0 = rng.uniform(1100, 1700)
    f = f0 * (1 + 0.5 * (1 - np.exp(-t * 60)))  # sube rapido: la gota
    x = sine(f, n) * np.exp(-t * 28) * 0.8
    x += tri(f * 2.0, n) * np.exp(-t * 60) * 0.15
    e = np.zeros(n + int(0.3 * SR))
    e[:n] += x
    d = int(rng.uniform(0.16, 0.24) * SR)  # eco hueco de la cueva
    e[d:d + n] += bw(x, None, 1500) * 0.28
    return fade(bits(e, 7), 0.003, 0.05)


def marble_echo(seed):
    rng = np.random.default_rng(seed)
    n = int(0.08 * SR)
    t = t_(n)
    f = rng.uniform(520, 760)
    x = tri(f + 0 * t, n) * np.exp(-t * 55) * 0.6 + bw(noise(rng, n), 2000, 5000) * np.exp(-t * 90) * 0.5
    x = echo(x, rng.uniform(0.2, 0.28), 0.62, 4)
    return fade(bits(x, 7), 0.003, 0.15)


def organic(seed):
    rng = np.random.default_rng(seed)
    n = int(rng.uniform(1.2, 1.8) * SR)
    t = t_(n)
    base = rng.uniform(70, 120)
    wob = 1 + 0.25 * np.sin(2 * np.pi * rng.uniform(1.5, 3.0) * t)
    x = sine(base * wob, n) * 0.7 + sine(base * 1.5 * wob, n) * 0.2
    x += bw(noise(rng, n), 120, 700) * 0.25
    env = np.sin(np.pi * np.clip(t / (n / SR), 0, 1)) ** 2
    env *= 0.6 + 0.4 * np.sin(2 * np.pi * rng.uniform(2.5, 4.0) * t) ** 2
    return fade(bits(x * env, 8), 0.05, 0.2)


def stamp(seed):
    rng = np.random.default_rng(seed)
    n = int(0.9 * SR)
    t = t_(n)
    x = sine(75 * np.exp(-t * 6) + 45, n) * np.exp(-t * 14)
    x += bw(noise(rng, n), 100, 500) * np.exp(-t * 18) * 0.6
    x = bw(x, None, 900)  # lejano, amortiguado
    d = int(0.35 * SR)
    x[d:] += x[:n - d] * 0.2  # rebote
    return fade(bits(x, 8), 0.004, 0.2)


def paper(seed):
    rng = np.random.default_rng(seed)
    n = int(rng.uniform(0.45, 0.7) * SR)
    t = t_(n)
    flutter = np.abs(np.sin(2 * np.pi * rng.uniform(9, 16) * t + rng.uniform(0, 3)))
    x = bw(noise(rng, n), 1800, 6000) * flutter
    x *= np.sin(np.pi * np.clip(t / (n / SR), 0, 1)) ** 1.5
    return fade(bits(x, 7), 0.02, 0.1)


# ------------------------------------------------------------------ camas (bucles)
LOOP_S = 20.0


def bed_selva():
    """Follaje: viento suave que respira lento + grillo lejano."""
    rng = np.random.default_rng(11)
    n = int(LOOP_S * SR)
    t = t_(n)
    x = bw(noise(rng, n), 250, 1400)
    x *= 0.55 + 0.45 * np.sin(2 * np.pi * (3 / LOOP_S) * t + 0.6)  # 3 respiraciones
    gate = ((np.sin(2 * np.pi * 7 * t) > 0.6) * (np.sin(2 * np.pi * (2 / LOOP_S) * t) > 0.3)).astype(float)
    gate = bw(gate, None, 60)  # puertas suaves: sin clics
    cr = tri(3300 + 0 * t, n) * np.clip(gate, 0, 1)
    return x / np.abs(x).max() * 0.5 + cr * 0.03


def bed_pene():
    """Sala de marmol: aire grave y dos tonos triangulares que baten."""
    rng = np.random.default_rng(12)
    n = int(LOOP_S * SR)
    t = t_(n)
    air = bw(noise(rng, n), 120, 600)
    air = air / np.abs(air).max() * 0.35
    f1 = 110.0
    f2 = 110.0 + 2 / LOOP_S * 5  # batido con periodo que cabe en el bucle
    tone = tri(f1 + 0 * t, n) * 0.5 + tri(f2 + 0 * t, n) * 0.5
    tone = bw(tone, None, 500) * (0.5 + 0.5 * np.sin(2 * np.pi * (2 / LOOP_S) * t))
    return air + tone * 0.35


def bed_vulva():
    """Latido organico: ruido grave que pulsa a 0.8 Hz."""
    rng = np.random.default_rng(13)
    n = int(LOOP_S * SR)
    t = t_(n)
    x = bw(noise(rng, n), 40, 260)
    x = x / np.abs(x).max()
    beat = 0.5 + 0.5 * np.sin(2 * np.pi * (16 / LOOP_S) * t)
    beat2 = 0.5 + 0.5 * np.sin(2 * np.pi * (16 / LOOP_S) * t - 0.9)
    pulse = beat ** 3 + 0.5 * beat2 ** 4
    thump = sine(55 + 0 * t, n) * pulse * 0.25
    return x * (0.25 + 0.55 * pulse) * 0.6 + thump


def bed_mixto():
    """Aduana: zumbido de fluorescente (100 Hz de red + armonicos)."""
    rng = np.random.default_rng(14)
    n = int(LOOP_S * SR)
    t = t_(n)
    hum = np.zeros(n)
    for k, a in [(1, 1.0), (2, 0.5), (3, 0.35), (5, 0.12), (7, 0.07)]:
        hum += a * np.sin(2 * np.pi * 100 * k * t + k)
    hum += bw(noise(rng, n), 2500, 5500) * 0.05
    # leve vacilacion periodica de la luz
    flick = 1 - 0.12 * np.clip(np.sin(2 * np.pi * (5 / LOOP_S) * t) * 6 - 5, 0, 1)
    return hum * flick * 0.5


def bed_prostata():
    """La Prostata: sala de espera. Hilo de aire acondicionado, zumbido de tubo y un goteo lejano."""
    rng = np.random.default_rng(16)
    n = int(LOOP_S * SR)
    t = t_(n)
    air = bw(noise(rng, n), 120, 700)
    air = air / np.abs(air).max() * 0.25
    hum = (np.sin(2 * np.pi * 60 * t) + 0.4 * np.sin(2 * np.pi * 120 * t)) * 0.12
    x = air + hum
    for k in range(3):  # gota cada ~LOOP_S/3, desfasada del inicio
        i = int((k + 0.4) * n / 3)
        m = int(0.18 * SR)
        tt = t_(m)
        x[i:i + m] += sine(900 + 500 * np.exp(-tt * 30), m) * np.exp(-tt * 28) * 0.18
    return x


def bed_censura():
    """Palacio: casi silencio. Retumbo muy grave y un reloj (tic-tac cada segundo)."""
    rng = np.random.default_rng(15)
    n = int(16 * SR)
    t = t_(n)
    x = bw(noise(rng, n), 30, 90)
    x = x / np.abs(x).max() * 0.35
    x += sine(48 + 0 * t, n) * 0.08 * (0.6 + 0.4 * np.sin(2 * np.pi * (1 / 16) * t))
    for s in range(16):
        i = s * SR + 400  # desfasado: el bucle no empieza en pleno clic
        m = int(0.12 * SR)
        tt = t_(m)
        f = 1500 if s % 2 == 0 else 1050
        click = tri(f + 0 * tt, m) * np.exp(-tt * 70) + bw(noise(rng, m), 1500, 5000) * np.exp(-tt * 120) * 0.6
        x[i:i + m] += click * 0.36
    return x


# ------------------------------------------------------------------ antorchas
def torch_loop():
    rng = np.random.default_rng(21)
    n = int(6.0 * SR)
    x = bw(noise(rng, n), 600, 2200) * 0.05
    x += bw(noise(rng, n), 60, 300) * 0.05
    for _ in range(34):
        i = int(rng.uniform(0, n))
        m = int(rng.uniform(0.004, 0.02) * SR)
        tt = t_(m)
        amp = rng.uniform(0.15, 0.6) * (2.2 if rng.random() < 0.08 else 1.0)
        pop = bw(noise(rng, m), 1500, 7000) * np.exp(-tt * (4.0 / (m / SR)))
        if rng.random() < 0.3:
            pop += sine(rng.uniform(900, 2400) + 0 * tt, m) * np.exp(-tt * 300) * 0.4
        idx = (i + np.arange(m)) % n  # da la vuelta: el bucle no tiene empalme
        x[idx] += pop * amp
    return bits(x / np.abs(x).max(), 8)


# ------------------------------------------------------------------ pasos
def step_dirt(seed):
    rng = np.random.default_rng(seed)
    n = int(0.16 * SR)
    t = t_(n)
    x = bw(noise(rng, n), 300, 1800) * np.exp(-t * 32)
    x += sine(rng.uniform(80, 110) + 0 * t, n) * np.exp(-t * 40) * 0.6
    g = np.zeros(n)  # granitos de tierra
    for _ in range(4):
        j = int(rng.uniform(0.02, 0.12) * SR)
        g[j:j + 40] += bw(noise(rng, 40), 1500, 6000) * 0.3
    return fade(bits(x + g, 7), 0.002, 0.04)


def step_marble(seed):
    rng = np.random.default_rng(seed)
    n = int(0.09 * SR)
    t = t_(n)
    f = rng.uniform(600, 820)
    x = bw(noise(rng, n), 2200, 6500) * np.exp(-t * 110) * 0.7
    x += tri(f + 0 * t, n) * np.exp(-t * 55) * 0.6
    out = np.zeros(int(0.32 * SR))
    out[:n] += x
    d = int(rng.uniform(0.08, 0.11) * SR)
    out[d:d + n] += bw(x, None, 1800) * 0.28
    return fade(bits(out, 7), 0.001, 0.08)


def step_organic(seed):
    rng = np.random.default_rng(seed)
    n = int(0.2 * SR)
    t = t_(n)
    f = rng.uniform(150, 220) * np.exp(-t * 7) + 60
    x = sine(f, n) * np.exp(-t * 16) * 0.8
    x += bw(noise(rng, n), 200, 1100) * np.exp(-t * 18) * 0.5
    x += bw(noise(rng, n), 1500, 3500) * np.exp(-t * 60) * 0.12 * (np.sin(2 * np.pi * 70 * t) > 0)
    return fade(bits(x, 8), 0.004, 0.06)


def step_cobble(seed):
    rng = np.random.default_rng(seed)
    n = int(0.17 * SR)
    t = t_(n)
    x = sine(rng.uniform(140, 190) * np.exp(-t * 4) + 0 * t, n) * np.exp(-t * 36)
    x += bw(noise(rng, n), 800, 3000) * np.exp(-t * 80) * 0.7
    j = int(rng.uniform(0.045, 0.06) * SR)  # segundo golpecito: el adoquin se mueve
    x[j:] += (bw(noise(rng, n), 600, 2500) * np.exp(-t * 90))[:n - j] * 0.35
    return fade(bits(x, 7), 0.001, 0.05)


def step_tile(seed):
    rng = np.random.default_rng(seed)
    n = int(0.12 * SR)
    t = t_(n)
    f = rng.uniform(1500, 2100)
    x = bw(noise(rng, n), 1000, 5000) * np.exp(-t * 90) * 0.7
    x += tri(f + 0 * t, n) * np.exp(-t * 60) * 0.35
    x += sine(rng.uniform(260, 330) + 0 * t, n) * np.exp(-t * 35) * 0.3  # hueco debajo
    return fade(bits(x, 7), 0.001, 0.04)


def splash(seed):
    rng = np.random.default_rng(seed)
    n = int(0.3 * SR)
    t = t_(n)
    x = bw(noise(rng, n), 500, 3500) * (np.exp(-t * 14) * 0.6)
    for _ in range(4):  # burbujas
        j = int(rng.uniform(0.01, 0.15) * SR)
        m = int(0.05 * SR)
        tt = t_(m)
        f = rng.uniform(500, 900) * (1 + 3 * tt)
        x[j:j + m] += sine(f, m) * np.exp(-tt * 45) * 0.35
    return fade(bits(x, 7), 0.003, 0.08)


# ------------------------------------------------------------------ generar
for i in range(3):
    save("amb_drip_%d" % i, drip(100 + i), peak=0.7)
    save("amb_marble_%d" % i, marble_echo(110 + i), peak=0.7)
    save("amb_organic_%d" % i, organic(120 + i), peak=0.7)
    save("amb_paper_%d" % i, paper(130 + i), peak=0.6)
    save("step_dirt_%d" % i, step_dirt(200 + i))
    save("step_marble_%d" % i, step_marble(210 + i))
    save("step_organic_%d" % i, step_organic(220 + i))
    save("step_cobble_%d" % i, step_cobble(230 + i))
    save("step_tile_%d" % i, step_tile(240 + i))
    save("splash_%d" % i, splash(250 + i), peak=0.8)
for i in range(2):
    save("amb_stamp_%d" % i, stamp(140 + i), peak=0.8)
save("bed_neutral", bed_selva(), loop=True, peak=0.6)
save("bed_pene", bed_pene(), loop=True, peak=0.6)
save("bed_vulva", bed_vulva(), loop=True, peak=0.6)
save("bed_mixto", bed_mixto(), loop=True, peak=0.6)
save("bed_censura", bed_censura(), loop=True, peak=0.6)
save("bed_prostata", bed_prostata(), loop=True, peak=0.6)
save("torch_loop", torch_loop(), loop=True, peak=0.8)

print("%-16s %6s %6s %6s  %s" % ("archivo", "dur s", "pico", "rms", "empalme / extremos"))
for name, dur, pk, rms, seam, typ, loop, a, b in REPORT:
    extra = ("bucle salto %.4f vs tipico %.4f" % (seam, typ)) if loop else ("ini %.3f fin %.3f" % (a, b))
    print("%-16s %6.2f %6.3f %6.3f  %s" % (name, dur, pk, rms, extra))
