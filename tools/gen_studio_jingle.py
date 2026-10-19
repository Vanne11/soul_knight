"""Jingle del estudio (C&B Studio) -> assets/audio/music/studio_jingle.ogg (~3.6 s, sin bucle).
Mismo estilo que el menu: chiptune mono, 16 bits, 22050 Hz. Do mayor: un "bloop"
de babosa, 5 notas saltarinas (do-mi-sol-la-do alto) y un acorde final con cola.
Melodia: cuadrada 50%; acorde: pulso 25% + bajo triangular.
Uso (desde la raiz del proyecto): python3 tools/gen_studio_jingle.py"""
import wave
import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from to_ogg import to_ogg
import numpy as np

SR = 22050
DUR = 3.6
out = np.zeros(int(SR * (DUR + 0.5)))


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def env(n, a=0.004, r=0.08):
    e = np.ones(n)
    na, nr = max(1, int(a * SR)), max(1, min(n, int(r * SR)))
    e[:na] *= np.linspace(0, 1, na)
    e[-nr:] *= np.linspace(1, 0, nr)
    return e


def put(t, sig):
    i = int(t * SR)
    out[i:i + len(sig)] += sig


def pulse(f, n, duty):
    ph = (np.arange(n) * f / SR) % 1.0
    return np.where(ph < duty, 1.0, -1.0)


def tri(f, n):
    ph = (np.arange(n) * f / SR) % 1.0
    return 4 * np.abs(ph - 0.5) - 1


# bloop inicial: seno que sube rapido
n = int(0.16 * SR)
tt = np.arange(n) / SR
f = 220 + 700 * tt / 0.16
put(0.0, np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, 0.003, 0.06) * 0.35)

# (inicio s, duracion s, midi)
notes = [(0.30, 0.20, 72), (0.62, 0.20, 76), (0.94, 0.20, 79), (1.26, 0.20, 81), (1.62, 0.30, 84)]
for t0, d, m in notes:
    n = int(d * SR)
    put(t0, pulse(hz(m), n, 0.5) * env(n) * 0.22)

# acorde final largo (Do mayor), con cola
n = int(1.7 * SR)
for m in (72, 76, 79):
    put(1.95, pulse(hz(m), n, 0.25) * env(n, 0.01, 1.2) * 0.09)
put(1.95, tri(hz(48), n) * env(n, 0.01, 1.2) * 0.25)

out = out[:int(SR * DUR)]
out[-int(0.05 * SR):] *= np.linspace(1, 0, int(0.05 * SR))
out *= 0.234 / np.sqrt((out ** 2).mean())  # mismo RMS que el resto de la musica
peak = float(np.abs(out).max())
if peak > 0.7:
    out *= 0.7 / peak
pcm = (np.clip(out, -1, 1) * 32767).astype("<i2")
with wave.open("assets/audio/music/studio_jingle.wav", "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
to_ogg("assets/audio/music/studio_jingle.wav")
print("studio_jingle.ogg", len(pcm) / SR, "s")
