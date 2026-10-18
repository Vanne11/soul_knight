"""Tema del menu principal -> assets/audio/music/menu.ogg (se escribe el wav y to_ogg.py lo convierte)
Chiptune sintetizado (mono, 16 bits, 22050 Hz: igual que explore.ogg).
Re menor natural, 96 BPM, progresion i-VI-III-VII (Dm-Bb-F-C), 16 compases
= 40 s. Melodia: cuadrada 50%; arpegio: pulso 25%; bajo: triangular;
percusion: bombo (seno que cae) + caja/hat de ruido.
Uso (desde la raiz del proyecto): python3 tools/gen_menu_music.py"""
import wave
from to_ogg import to_ogg
import numpy as np

SR = 22050
BPM = 96
E8 = 60.0 / BPM / 2          # corchea (s)
BARS = 16
N = int(SR * E8 * 8 * BARS)
rng = np.random.default_rng(7)  # ruido reproducible


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def env(n, a=0.004, r=0.05, sustain=1.0):
    e = np.ones(n) * sustain
    na, nr = max(1, int(a * SR)), max(1, min(n, int(r * SR)))
    e[:na] *= np.linspace(0, 1, na)
    e[-nr:] *= np.linspace(1, 0, nr)
    return e


def pulse(f, n, duty, vib=0.0):
    """Onda de pulso; vib = profundidad de vibrato (crece con la nota)."""
    t = np.arange(n) / SR
    mod = 1 + vib * np.sin(2 * np.pi * 5.5 * t) * np.linspace(0, 1, n)
    ph = (np.cumsum(f * mod) / SR) % 1.0
    return np.where(ph < duty, 1.0, -1.0)


def tri(f, n):
    ph = (np.arange(n) * f / SR) % 1.0
    return 4 * np.abs(ph - 0.5) - 1


out = np.zeros(N + SR)


def put(t, sig):
    i = int(t * SR)
    out[i:i + len(sig)] += sig


# (raiz grave del bajo, tres notas del arpegio) por compas: Dm, Bb, F, C
CH = [(38, [62, 65, 69]), (34, [58, 62, 65]), (41, [60, 65, 69]), (36, [60, 64, 67])]

# Melodia en frases de 4 compases = 32 corcheas: (inicio, duracion, midi)
PA1 = [(0, 3, 74), (3, 1, 72), (4, 2, 69), (6, 2, 70),
       (8, 3, 70), (11, 1, 69), (12, 2, 65), (14, 2, 69),
       (16, 3, 72), (19, 1, 70), (20, 2, 69), (22, 2, 72),
       (24, 4, 71), (28, 2, 67), (30, 2, 64)]
PA2 = [(0, 3, 74), (3, 1, 76), (4, 2, 77), (6, 2, 74),
       (8, 3, 70), (11, 1, 72), (12, 2, 74), (14, 2, 70),
       (16, 2, 72), (18, 2, 69), (20, 2, 65), (22, 2, 69),
       (24, 2, 67), (26, 2, 64), (28, 4, 62)]
PB1 = [(0, 1, 81), (1, 1, 77), (2, 2, 74), (4, 1, 77), (5, 1, 74), (6, 2, 69),
       (8, 1, 82), (9, 1, 77), (10, 2, 74), (12, 1, 77), (13, 1, 74), (14, 2, 70),
       (16, 1, 81), (17, 1, 77), (18, 2, 72), (20, 1, 77), (21, 1, 72), (22, 2, 69),
       (24, 2, 79), (26, 2, 76), (28, 2, 72), (30, 2, 67)]
PB2 = [(0, 3, 81), (3, 1, 79), (4, 2, 77), (6, 2, 74),
       (8, 3, 82), (11, 1, 81), (12, 2, 77), (14, 2, 74),
       (16, 2, 76), (18, 2, 77), (20, 2, 81), (22, 2, 77),
       (24, 2, 76), (26, 2, 72), (28, 2, 64), (30, 2, 62)]
PHR = [PA1, PA2, PB1, PB2]

for ph, notes in enumerate(PHR):
    for s, d, m in notes:
        n = int(d * E8 * SR * 0.92)
        sig = pulse(hz(m), n, 0.5, 0.004 if d >= 3 else 0.0) * env(n, 0.005, 0.06, 0.8)
        put((ph * 32 + s) * E8, sig * (0.16 if ph < 2 else 0.20))

for bar in range(BARS):
    root, notes3 = CH[bar % 4]
    t0 = bar * 8 * E8
    pat = [0, 0, 12, 0, 0, 0, 12, 7]  # bajo: raiz, octava y quinta
    for k in range(8):
        n = int(E8 * SR * 0.9)
        put(t0 + k * E8, tri(hz(root + pat[k]), n) * env(n, 0.003, 0.03) * 0.42)
    amp = 0.07 if bar < 8 else 0.10  # el arpegio crece en la frase B
    for k in range(8):
        m = notes3[[0, 1, 2, 1][k % 4]] + (12 if k >= 4 else 0)
        n = int(E8 * SR * 0.38)
        put(t0 + k * E8, pulse(hz(m), n, 0.25) * env(n, 0.002, 0.04) * amp)
    for beat in range(4):
        tb = t0 + beat * 2 * E8
        if beat in (0, 2):  # bombo
            n = int(0.14 * SR)
            tt = np.arange(n) / SR
            f = 130 * np.exp(-tt * 28) + 45
            put(tb, np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 18) * 0.38)
        else:  # caja
            n = int(0.11 * SR)
            tt = np.arange(n) / SR
            put(tb, rng.uniform(-1, 1, n) * np.exp(-tt * 28) * 0.28)
    for k in range(8):  # hat en corcheas, contratiempos algo mas fuertes
        n = int(0.03 * SR)
        tt = np.arange(n) / SR
        put(t0 + k * E8, rng.uniform(-1, 1, n) * np.exp(-tt * 140) * (0.10 if k % 2 else 0.05))

out = out[:N]
# Mismo RMS que el resto de la musica (explore = 0.234), y si el pico pasa de 0.7 se baja todo (sin saturar)
target_rms = 0.234
out *= target_rms / np.sqrt((out ** 2).mean())
peak = float(np.abs(out).max())
if peak > 0.7:
    out *= 0.7 / peak
pcm = (np.clip(out, -1, 1) * 32767).astype("<i2")
with wave.open("assets/audio/music/menu.wav", "wb") as f:
    f.setnchannels(1)
    f.setsampwidth(2)
    f.setframerate(SR)
    f.writeframes(pcm.tobytes())
to_ogg("assets/audio/music/menu.wav")  # el juego usa menu.ogg
print("menu.ogg", len(pcm) / SR, "s  rms", float(np.sqrt((out ** 2).mean())), "pico", float(np.abs(out).max()))
