"""Sonidos de aviso de los jefes por tipo de ataque -> assets/audio/sfx/aviso_*.wav (mono 22050 Hz, 16 bit).
Solo biblioteca estandar: python3 tools/gen_boss_aviso_sfx.py"""
import math, random, struct, wave, os

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx")


def save(name, samples):
    peak = max(abs(s) for s in samples) or 1.0
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(SR)
        f.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s / peak * 0.7)) * 32767)) for s in samples))


def env(i, n, a=0.05):
    t = i / n
    return min(1.0, t / a) * (1.0 - t) ** 1.5


def embestida():  # grave que sube rapido + ruido: "viene encima"
    n = int(SR * 0.32); random.seed(1); out = []; ph = 0.0
    for i in range(n):
        t = i / n
        ph += 2 * math.pi * (90 + 330 * t * t) / SR
        out.append((math.sin(ph) * 0.8 + (random.random() * 2 - 1) * 0.25 * t) * env(i, n, 0.08))
    save("aviso_embestida", out)


def zona():  # dos golpes graves pulsantes: "cuidado con el piso"
    n = int(SR * 0.4); out = []
    for i in range(n):
        t = i / SR
        a = 0.0
        for k, st in enumerate((0.0, 0.18)):
            if t >= st:
                d = t - st
                a += math.sin(2 * math.pi * (150 - 60 * d) * d) * math.exp(-d * 14)
        out.append(a)
    save("aviso_zona", out)


def proyectil():  # doble pitido agudo
    n = int(SR * 0.26); out = []
    for i in range(n):
        t = i / SR
        f = 1180 if t < 0.12 else 1560
        local = t if t < 0.12 else t - 0.12
        out.append(math.sin(2 * math.pi * f * t) * math.exp(-local * 22) * (1 if local < 0.1 else 0.0 if False else 1))
    save("aviso_proyectil", out)


def cura():  # campana suave que sube: "se esta curando"
    n = int(SR * 0.55); out = []
    for i in range(n):
        t = i / SR
        f = 392 + 260 * (t / 0.55)
        out.append((math.sin(2 * math.pi * f * t) + 0.4 * math.sin(2 * math.pi * f * 2.01 * t)) * env(i, n, 0.15))
    save("aviso_cura", out)


for fn in (embestida, zona, proyectil, cura):
    fn()
print("listo")
