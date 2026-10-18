"""Musica por reino -> assets/audio/music/explore_<reino>.ogg y boss_<reino>.ogg (escribe el wav y to_ogg.py lo convierte)
Chiptune sintetizado (mono, 16 bits, 22050 Hz: igual que explore.ogg), mismo
estilo que tools/gen_menu_music.py. Cada tema es un bucle limpio: las colas de
las notas dan la vuelta al principio (empalme sin clic).

Reinos (RunManager.floor_data().kingdom):
  neutral  Selva Pubica        do mixolidio, saltarin, plucks y bongos
  pene     Penelandia          re dorico, fanfarria "griega", timbales
  vulva    Vulvania            fa lidio, calido, campanitas y latido
  mixto    El Perineo          la menor armonica, oficina tensa, maquina de escribir
  censura  Palacio Censura     mi frigio, frio y rigido, campana de bronce, coro
  prostata La Prostata         sol dorico MUY lento, musica de ascensor, hilo de saxo

Estructura: cada tema son secciones (A, B, A', C...) de compases con una
progresion de grados (acordes apilados en la escala) y motivos de un compas en
grados relativos a la raiz del acorde. El jefe usa el MISMO motivo en una escala
mas oscura, mas rapido y con mas capas.
Uso (desde la raiz del proyecto): python3 tools/gen_floor_music.py [reino ...]"""
import sys
import wave
from to_ogg import to_ogg
import numpy as np

SR = 22050
TARGET_RMS = 0.234   # explore.ogg = 0.234
PEAK = 0.70          # como el resto de la musica

SCALES = {
    "mixolidio": [0, 2, 4, 5, 7, 9, 10],
    "eolia": [0, 2, 3, 5, 7, 8, 10],
    "dorico": [0, 2, 3, 5, 7, 9, 10],
    "frigio_dom": [0, 1, 4, 5, 7, 8, 10],
    "lidio": [0, 2, 4, 6, 7, 9, 11],
    "menor_arm": [0, 2, 3, 5, 7, 8, 11],
    "frigio": [0, 1, 3, 5, 7, 8, 10],
    "disminuida": [0, 2, 3, 5, 6, 8, 9],  # (7 notas de la octatonica, sin la ultima)
}


def fold(m, top=84):
    """Baja octavas hasta que quepa (evita agudos que aliasean a 22 kHz)."""
    while m > top:
        m -= 12
    return m


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def deg2midi(tonic, scale, d):
    s = SCALES[scale]
    return tonic + 12 * (d // 7) + s[d % 7]


# ---------------------------------------------------------------- sintesis
def env(n, a=0.004, r=0.05, sustain=1.0, decay=0.0):
    t = np.arange(n) / SR
    e = np.ones(n) * sustain
    if decay > 0:
        e = e * np.exp(-t * decay)
    na, nr = max(1, int(a * SR)), max(1, min(n, int(r * SR)))
    e[:na] *= np.linspace(0, 1, min(na, n))[:na] if na <= n else 1
    e[-nr:] *= np.linspace(1, 0, nr)
    return e


def osc(kind, f, n, vib=0.0, slide=0.0):
    t = np.arange(n) / SR
    mod = 1 + vib * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1, t * 4)
    if slide:
        mod = mod * (1 + slide * np.exp(-t * 18))
    ph = (np.cumsum(f * mod) / SR) % 1.0
    if kind == "sq":
        return np.where(ph < 0.5, 1.0, -1.0)
    if kind == "p25":
        return np.where(ph < 0.25, 1.0, -1.0)
    if kind == "p12":
        return np.where(ph < 0.125, 1.0, -1.0)
    if kind == "tri":
        return 4 * np.abs(ph - 0.5) - 1
    if kind == "saw":
        return 2 * ph - 1
    if kind == "sine":
        return np.sin(2 * np.pi * ph)
    if kind == "choir":  # dos sierras desafinadas + una octava: coro de pobre
        p2 = (np.cumsum(f * 1.006 * mod) / SR) % 1.0
        p3 = (np.cumsum(f * 0.994 * mod) / SR) % 1.0
        return (2 * ph - 1 + 2 * p2 - 1 + 2 * p3 - 1) / 3
    if kind == "bell":  # FM inarmonico
        return np.sin(2 * np.pi * ph + 2.2 * np.exp(-t * 4) * np.sin(2 * np.pi * ph * 3.5))
    if kind == "bronze":  # campana de bronce, parciales inarmonicos
        return (np.sin(2 * np.pi * ph) + 0.6 * np.sin(2 * np.pi * ph * 2.76)
                + 0.4 * np.sin(2 * np.pi * ph * 5.4) + 0.25 * np.sin(2 * np.pi * ph * 8.9)) / 2.2
    return np.zeros(n)


# instrumento -> (oscilador, ataque, release, sustain, decay, vibrato, slide)
INSTR = {
    "sq": ("sq", 0.005, 0.06, 0.8, 0.0, 0.0, 0.0),
    "sqv": ("sq", 0.01, 0.06, 0.8, 0.0, 0.005, 0.0),
    "p25": ("p25", 0.003, 0.04, 0.8, 0.0, 0.0, 0.0),
    "marimba": ("p12", 0.002, 0.04, 1.0, 9.0, 0.0, 0.0),
    "pluck": ("p25", 0.002, 0.04, 1.0, 8.0, 0.0, 0.0),
    "lira": ("tri", 0.002, 0.05, 1.0, 5.0, 0.0, 0.0),
    "brass": ("saw", 0.03, 0.07, 0.8, 0.0, 0.006, 0.0),
    "kazoo": ("saw", 0.01, 0.05, 0.8, 0.0, 0.004, -0.06),
    "bell": ("bell", 0.001, 0.2, 1.0, 3.0, 0.0, 0.0),
    "bronze": ("bronze", 0.001, 0.3, 1.0, 1.4, 0.0, 0.0),
    "sax": ("saw", 0.06, 0.16, 0.7, 0.0, 0.014, 0.05),
    "choir": ("choir", 0.08, 0.12, 0.9, 0.0, 0.004, 0.0),
    "tri": ("tri", 0.004, 0.04, 1.0, 0.0, 0.0, 0.0),
    "sine": ("sine", 0.01, 0.08, 1.0, 0.0, 0.0, 0.0),
    "saw": ("saw", 0.004, 0.04, 0.9, 0.0, 0.0, 0.0),
}


def note(inst, m, n):
    o, a, r, s, d, v, sl = INSTR[inst]
    return osc(o, hz(m), n, v, sl) * env(n, a, r, s, d)


class Track:
    def __init__(self, nbars, e8, seed):
        self.e8 = e8
        self.N = int(round(SR * e8 * 8 * nbars))
        self.out = np.zeros(self.N)
        self.rng = np.random.default_rng(seed)

    def put(self, t, sig, g=1.0):
        """Mezcla con vuelta al principio (bucle sin clic)."""
        i = int(t * SR) % self.N
        n = len(sig)
        if i + n <= self.N:
            self.out[i:i + n] += sig * g
        else:
            k = self.N - i
            self.out[i:] += sig[:k] * g
            self.out[:n - k] += sig[k:] * g

    def kick(self, t, g=0.38, deep=45):
        n = int(0.16 * SR)
        tt = np.arange(n) / SR
        f = 130 * np.exp(-tt * 28) + deep
        self.put(t, np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 18), g)

    def snare(self, t, g=0.28):
        n = int(0.12 * SR)
        tt = np.arange(n) / SR
        self.put(t, self.rng.uniform(-1, 1, n) * np.exp(-tt * 26), g)

    def hat(self, t, g=0.07, d=140):
        n = int(0.04 * SR)
        tt = np.arange(n) / SR
        self.put(t, self.rng.uniform(-1, 1, n) * np.exp(-tt * d), g)

    def tom(self, t, f0=95, g=0.4, d=14):
        n = int(0.28 * SR)
        tt = np.arange(n) / SR
        f = f0 * (1 + 0.6 * np.exp(-tt * 30))
        s = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.3 * self.rng.uniform(-1, 1, n) * np.exp(-tt * 60)
        self.put(t, s * np.exp(-tt * d), g)

    def bongo(self, t, f0=300, g=0.22):
        n = int(0.09 * SR)
        tt = np.arange(n) / SR
        f = f0 * (1 + 0.4 * np.exp(-tt * 60))
        self.put(t, np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 38), g)

    def clack(self, t, g=0.2):  # tecla de maquina de escribir
        n = int(0.025 * SR)
        tt = np.arange(n) / SR
        s = self.rng.uniform(-1, 1, n) * np.exp(-tt * 220) + 0.6 * np.sin(2 * np.pi * 1800 * tt) * np.exp(-tt * 200)
        self.put(t, s, g)

    def crash(self, t, g=0.2):
        n = int(0.9 * SR)
        tt = np.arange(n) / SR
        self.put(t, self.rng.uniform(-1, 1, n) * np.exp(-tt * 5), g)


# ---------------------------------------------------------------- partitura
# Un motivo de compas = [(inicio_corchea, duracion, grado_relativo_a_la_raiz)]
# Reino -> dict con ajustes de explore ("e") y de jefe ("b").
# Cada version: tonic, scale, bpm, secciones [(nombre, compases, prog, motivos, capas)]
# motivos: (m1, m2, m3) -> compas 1 y 3 de la frase usan m1/m2 alternando, el 4 cierra con m3
# capas: m=melodia, a=arpegio, b=bajo, d=bateria, p=pad, h=melodia octava arriba

def M(*notes):
    return list(notes)


# ----- Selva Pubica: saltarina, sincopada
SEL_A = (M((0, 1, 4), (1, 1, 2), (2, 2, 0), (4, 1, 2), (5, 1, 4), (6, 2, 7)),
         M((0, 1, 7), (1, 1, 4), (2, 2, 2), (4, 1, 4), (5, 3, 2)),
         M((0, 2, 4), (2, 1, 2), (3, 1, 0), (4, 2, 2), (6, 2, -1)))
SEL_B = (M((0, 1, 7), (1, 1, 9), (2, 1, 7), (3, 1, 4), (4, 2, 9), (6, 2, 7)),
         M((0, 2, 9), (2, 1, 7), (3, 1, 4), (4, 1, 7), (5, 1, 4), (6, 2, 2)),
         M((0, 1, 4), (1, 1, 2), (2, 1, 0), (3, 1, 2), (4, 4, 0)))
# ----- Penelandia: fanfarria
PEN_A = (M((0, 3, 0), (3, 1, 0), (4, 2, 4), (6, 2, 2)),
         M((0, 3, 4), (3, 1, 4), (4, 2, 7), (6, 2, 4)),
         M((0, 2, 7), (2, 2, 4), (4, 2, 2), (6, 2, 0)))
PEN_B = (M((0, 1, 7), (1, 1, 6), (2, 1, 7), (3, 1, 9), (4, 4, 11)),
         M((0, 1, 9), (1, 1, 7), (2, 1, 9), (3, 1, 11), (4, 4, 14)),
         M((0, 2, 11), (2, 2, 9), (4, 2, 7), (6, 2, 4)))
# ----- Vulvania: suave, ondulante
VUL_A = (M((0, 2, 4), (2, 2, 7), (4, 3, 9), (7, 1, 7)),
         M((0, 2, 7), (2, 2, 4), (4, 4, 2)),
         M((0, 3, 4), (3, 1, 2), (4, 2, 0), (6, 2, 2)))
VUL_B = (M((0, 1, 9), (1, 1, 11), (2, 2, 14), (4, 2, 11), (6, 2, 9)),
         M((0, 2, 11), (2, 1, 9), (3, 1, 7), (4, 4, 9)),
         M((0, 2, 7), (2, 2, 4), (4, 4, 0)))
# ----- Perineo: staccato, cromatico, burocratico
PER_A = (M((0, 1, 0), (1, 1, 0), (2, 1, 1), (3, 1, 0), (4, 1, -1), (5, 3, 0)),
         M((0, 1, 4), (1, 1, 4), (2, 1, 5), (3, 1, 4), (4, 1, 2), (5, 3, 4)),
         M((0, 1, 7), (1, 1, 5), (2, 1, 4), (3, 1, 2), (4, 4, 0)))
PER_B = (M((0, 2, 7), (2, 1, 6), (3, 1, 7), (4, 2, 4), (6, 2, 2)),
         M((0, 2, 9), (2, 1, 8), (3, 1, 9), (4, 2, 7), (6, 2, 4)),
         M((0, 1, 4), (1, 1, 2), (2, 1, 0), (3, 1, -1), (4, 4, 0)))
# ----- Palacio: lento, grave, rigido
CEN_A = (M((0, 4, 0), (4, 2, 1), (6, 2, 0)),
         M((0, 4, 4), (4, 2, 3), (6, 2, 4)),
         M((0, 2, 4), (2, 2, 3), (4, 2, 1), (6, 2, 0)))
CEN_B = (M((0, 1, 7), (1, 1, 7), (2, 1, 7), (3, 1, 8), (4, 4, 7)),
         M((0, 1, 8), (1, 1, 8), (2, 1, 8), (3, 1, 9), (4, 4, 8)),
         M((0, 2, 7), (2, 2, 4), (4, 4, 0)))

# ----- La Prostata: sala de espera, notas largas con silencios, saxo que no se decide
PRO_A = (M((0, 3, 4), (4, 4, 2)),
         M((0, 2, 2), (3, 1, 4), (4, 4, 0)),
         M((0, 4, 4), (5, 2, 2), (7, 1, 0)))
PRO_B = (M((1, 2, 7), (4, 3, 4)),
         M((0, 3, 5), (4, 1, 4), (6, 2, 2)),
         M((0, 2, 4), (3, 1, 2), (4, 4, 0)))

# Perfiles de capas por seccion
FULL = "mabdp"
SOFT = "mabd"
BREAK = "apm"
BUILD = "abdh"
BIG = "mabdph"

THEMES = {
    "neutral": {
        "e": dict(tonic=60, scale="mixolidio", bpm=116, lead="marimba", lead2="p25", arp="pluck",
                  bass="tri", pad="sine", motifs=(SEL_A, SEL_B), swing=0.12, seed=1,
                  bpat=[0, None, 7, None, 0, None, 7, 4], bass_oct=-24,
                  drums={"k": "k.b.k.b.", "s": "..b...b.", "h": "h.h.h.hh"},
                  secs=[("A", 8, [0, 6, 3, 0, 0, 6, 3, 4], 0, "mabd"),
                        ("B", 8, [3, 0, 3, 0, 4, 3, 0, 4], 1, "mabdh"),
                        ("A", 8, [0, 6, 3, 0, 0, 6, 3, 4], 0, "mabdp"),
                        ("C", 8, [5, 3, 0, 4, 5, 3, 4, 0], 1, "apbm")]),
        "b": dict(tonic=60, scale="eolia", bpm=148, lead="sqv", lead2="p25", arp="p25",
                  bass="saw", pad="sine", motifs=(SEL_A, SEL_B), swing=0.0, seed=11,
                  bpat=[0, 0, 12, 0, 0, 7, 12, 10], bass_oct=-24,
                  drums={"k": "k.k.k.kk", "s": "..s...s.", "h": "hhhhhhhh"},
                  secs=[("A", 8, [0, 5, 3, 4, 0, 5, 3, 6], 0, "mabd"),
                        ("B", 8, [5, 3, 0, 6, 5, 3, 6, 4], 1, "mabdh"),
                        ("A", 8, [0, 5, 3, 4, 0, 5, 3, 6], 0, "mabdph"),
                        ("C", 8, [3, 4, 5, 6, 3, 4, 6, 4], 1, "mabdph"),
                        ("A", 8, [0, 5, 3, 4, 0, 5, 3, 6], 0, "mabdph")]),
    },
    "pene": {
        "e": dict(tonic=62, scale="dorico", bpm=100, lead="brass", lead2="sq", arp="lira",
                  bass="tri", pad="sine", motifs=(PEN_A, PEN_B), swing=0.0, seed=2,
                  bpat=[0, None, None, None, 7, None, 0, None], bass_oct=-24,
                  drums={"k": "k...k...", "s": "..t...t.", "h": "h.h.h.h."},
                  secs=[("A", 8, [0, 3, 0, 3, 0, 3, 5, 4], 0, "mabd"),
                        ("B", 8, [3, 4, 3, 0, 5, 4, 5, 4], 1, "mabdp"),
                        ("A", 8, [0, 3, 0, 3, 0, 3, 5, 4], 0, "mabdph"),
                        ("C", 8, [5, 3, 0, 0, 5, 3, 4, 4], 1, "apm")]),
        "b": dict(tonic=62, scale="frigio_dom", bpm=140, lead="brass", lead2="saw", arp="lira",
                  bass="saw", pad="sine", motifs=(PEN_A, PEN_B), swing=0.0, seed=12,
                  bpat=[0, 0, 0, 0, 7, 0, 7, 0], bass_oct=-24,
                  drums={"k": "k.kkk.k.", "s": "t.t.t.tt", "h": "hhhhhhhh"},
                  secs=[("A", 8, [0, 1, 0, 1, 0, 1, 3, 4], 0, "mabd"),
                        ("B", 8, [3, 4, 3, 0, 1, 4, 1, 4], 1, "mabdh"),
                        ("A", 8, [0, 1, 0, 1, 0, 1, 3, 4], 0, "mabdph"),
                        ("C", 8, [5, 3, 1, 0, 5, 3, 4, 4], 1, "mabdph"),
                        ("A", 8, [0, 1, 0, 1, 0, 1, 3, 4], 0, "mabdph")]),
    },
    "vulva": {
        "e": dict(tonic=65, scale="lidio", bpm=92, lead="bell", lead2="sine", arp="lira",
                  bass="tri", pad="sine", motifs=(VUL_A, VUL_B), swing=0.06, seed=3,
                  bpat=[0, None, None, 7, None, None, 0, None], bass_oct=-24,
                  drums={"k": "k..k....", "s": "....s...", "h": "..h...h."},
                  secs=[("A", 8, [0, 4, 5, 3, 0, 4, 1, 4], 0, "mabp"),
                        ("B", 8, [3, 1, 4, 0, 3, 1, 4, 4], 1, "mabdp"),
                        ("A", 8, [0, 4, 5, 3, 0, 4, 1, 4], 0, "mabdph"),
                        ("C", 8, [5, 3, 1, 4, 5, 3, 4, 0], 1, "apm")]),
        "b": dict(tonic=65, scale="menor_arm", bpm=132, lead="bell", lead2="sine", arp="lira",
                  bass="tri", pad="sine", motifs=(VUL_A, VUL_B), swing=0.0, seed=13,
                  bpat=[0, None, 0, 7, None, 0, 7, None], bass_oct=-24,
                  drums={"k": "k..kk...", "s": "....s..s", "h": "h.h.h.hh"},
                  secs=[("A", 8, [0, 5, 3, 4, 0, 5, 1, 4], 0, "mabdp"),
                        ("B", 8, [3, 5, 4, 0, 3, 5, 4, 4], 1, "mabdph"),
                        ("A", 8, [0, 5, 3, 4, 0, 5, 1, 4], 0, "mabdph"),
                        ("C", 8, [5, 3, 1, 4, 5, 3, 4, 4], 1, "mabdph"),
                        ("A", 8, [0, 5, 3, 4, 0, 5, 1, 4], 0, "mabdph")]),
    },
    "mixto": {
        "e": dict(tonic=57, scale="menor_arm", bpm=124, lead="kazoo", lead2="sq", arp="pluck",
                  bass="saw", pad="sine", motifs=(PER_A, PER_B), swing=0.0, seed=4,
                  bpat=[0, 0, None, 0, 0, None, 0, 1], bass_oct=-24,
                  drums={"k": "k...k...", "s": "..c...c.", "h": "cccccccc"},
                  secs=[("A", 8, [0, 4, 0, 4, 3, 4, 0, 4], 0, "mabd"),
                        ("B", 8, [3, 4, 0, 4, 3, 5, 4, 4], 1, "mabdh"),
                        ("A", 8, [0, 4, 0, 4, 3, 4, 0, 4], 0, "mabdp"),
                        ("C", 8, [5, 4, 5, 4, 0, 4, 0, 4], 1, "abdm")]),
        "b": dict(tonic=57, scale="disminuida", bpm=156, lead="kazoo", lead2="saw", arp="p25",
                  bass="saw", pad="sine", motifs=(PER_A, PER_B), swing=0.0, seed=14,
                  bpat=[0, 0, 0, 1, 0, 0, 1, 0], bass_oct=-24,
                  drums={"k": "k.k.k.kk", "s": "..c.s.c.", "h": "cchcchch"},
                  secs=[("A", 8, [0, 4, 0, 4, 3, 4, 0, 4], 0, "mabd"),
                        ("B", 8, [3, 4, 0, 4, 3, 5, 4, 4], 1, "mabdh"),
                        ("A", 8, [0, 4, 0, 4, 3, 4, 0, 4], 0, "mabdph"),
                        ("C", 8, [5, 4, 5, 4, 0, 4, 0, 4], 1, "mabdph"),
                        ("A", 8, [0, 4, 0, 4, 3, 4, 0, 4], 0, "mabdph")]),
    },
    "prostata": {
        "e": dict(tonic=55, scale="dorico", bpm=66, lead="sax", lead2="sine", arp="lira",
                  bass="tri", pad="sine", motifs=(PRO_A, PRO_B), swing=0.1, seed=6,
                  bpat=[0, None, None, None, 7, None, None, None], bass_oct=-24,
                  drums={"k": "........", "s": "........", "h": "..h...h."},
                  secs=[("A", 8, [0, 3, 0, 3, 4, 3, 0, 3], 0, "mabp"),
                        ("B", 8, [3, 4, 3, 0, 5, 4, 3, 4], 1, "mabdp"),
                        ("A", 8, [0, 3, 0, 3, 4, 3, 0, 3], 0, "mabp"),
                        ("C", 8, [5, 3, 0, 3, 5, 4, 0, 0], 1, "apm")]),
        "b": dict(tonic=55, scale="menor_arm", bpm=104, lead="sax", lead2="saw", arp="lira",
                  bass="saw", pad="sine", motifs=(PRO_A, PRO_B), swing=0.0, seed=16,
                  bpat=[0, None, 0, None, 7, None, 0, None], bass_oct=-24,
                  drums={"k": "k..k..k.", "s": "....s...", "h": "h.h.h.h."},
                  secs=[("A", 8, [0, 3, 0, 3, 4, 3, 0, 3], 0, "mabd"),
                        ("B", 8, [3, 4, 3, 0, 5, 4, 3, 4], 1, "mabdh"),
                        ("A", 8, [0, 1, 0, 1, 4, 3, 0, 3], 0, "mabdph"),
                        ("C", 8, [5, 3, 1, 3, 5, 4, 3, 4], 1, "mabdph"),
                        ("A", 8, [0, 1, 0, 1, 4, 3, 0, 3], 0, "mabdph")]),
    },
    "censura": {
        "e": dict(tonic=52, scale="frigio", bpm=84, lead="sq", lead2="bronze", arp="p25",
                  bass="saw", pad="choir", motifs=(CEN_A, CEN_B), swing=0.0, seed=5,
                  bpat=[0, 0, 0, 0, 0, 0, 0, 0], bass_oct=-12,
                  drums={"k": "k.......", "s": "....s...", "h": "h.h.h.h."},
                  secs=[("A", 8, [0, 1, 0, 1, 0, 1, 5, 4], 0, "mabp"),
                        ("B", 8, [0, 1, 0, 1, 5, 1, 4, 4], 1, "mabdp"),
                        ("A", 8, [0, 1, 0, 1, 0, 1, 5, 4], 0, "mabdp"),
                        ("C", 8, [5, 4, 3, 4, 5, 4, 1, 0], 1, "apm")]),
        "b": dict(tonic=52, scale="frigio_dom", bpm=138, lead="sq", lead2="brass", arp="p25",
                  bass="saw", pad="choir", motifs=(CEN_A, CEN_B), swing=0.0, seed=15,
                  bpat=[0, 0, 12, 0, 0, 0, 12, 0], bass_oct=-12,
                  drums={"k": "k.kkk.k.", "s": "..s.s.ss", "h": "hhhhhhhh"},
                  secs=[("A", 8, [0, 1, 0, 1, 0, 1, 5, 4], 0, "mabp"),
                        ("B", 8, [0, 1, 0, 1, 5, 1, 4, 4], 1, "mabdph"),
                        ("A", 8, [0, 1, 0, 1, 0, 1, 5, 4], 0, "mabdph"),
                        # coro y orquesta: sube un tono, el tramo mas grande
                        ("C", 8, [3, 4, 5, 4, 3, 4, 5, 6], 1, "mabdph", 2),
                        ("C", 8, [3, 4, 5, 4, 3, 4, 5, 6], 0, "mabdph", 2),
                        ("B", 8, [0, 1, 0, 1, 5, 1, 4, 4], 1, "mabdph"),
                        ("A", 8, [0, 1, 0, 1, 0, 1, 5, 4], 0, "mabdph")]),
    },
}


def chord(tonic, scale, root_deg):
    return [deg2midi(tonic, scale, root_deg + k) for k in (0, 2, 4)]


def render(kingdom, kind):
    cfg = THEMES[kingdom][kind]
    boss = kind == "b"
    bpm = cfg["bpm"]
    e8 = 60.0 / bpm / 2
    secs = cfg["secs"]
    nbars = sum(s[1] for s in secs)
    tr = Track(nbars, e8, cfg["seed"])
    tonic0, scale = cfg["tonic"], cfg["scale"]
    mot_a, mot_b = cfg["motifs"]
    swing = cfg["swing"]
    bar0 = 0
    for si, sec in enumerate(secs):
        name, nb, prog, which, layers = sec[:5]
        tonic = tonic0 + (sec[5] if len(sec) > 5 else 0)
        motifs = (mot_a, mot_b)[which]
        last = si == len(secs) - 1
        for b in range(nb):
            bar = bar0 + b
            t0 = bar * 8 * e8
            root = prog[b % len(prog)]
            ch = chord(tonic, scale, root)
            # ---- melodia: frase de 4 compases (m1, m2, m1 variado, cierre m3)
            pos = b % 4
            mo = [motifs[0], motifs[1], motifs[0], motifs[2]][pos]
            vary = (b // 4) % 2 == 1  # la segunda frase de cada seccion se adorna
            if "m" in layers or "h" in layers:
                for s, d, rel in mo:
                    deg = root + rel + (1 if (vary and pos == 2 and rel == 4) else 0)
                    m = deg2midi(tonic, scale, deg) + 12
                    ts = t0 + s * e8 + (swing * e8 if s % 2 else 0)
                    n = int(d * e8 * SR * 0.92)
                    if "m" in layers:
                        tr.put(ts, note(cfg["lead"], fold(m), n), 0.20)
                    if "h" in layers:
                        tr.put(ts, note(cfg["lead2"], fold(m + 12, 90), n), 0.10)
            # ---- bajo
            if "b" in layers:
                for k in range(8):
                    o = cfg["bpat"][k]
                    if o is None:
                        continue
                    m = deg2midi(tonic, scale, root) + cfg["bass_oct"] + o
                    if m < 28:
                        m += 12
                    n = int(e8 * SR * 0.9)
                    tr.put(t0 + k * e8, note(cfg["bass"], m, n), 0.36 if cfg["bass"] == "tri" else 0.22)
            # ---- arpegio
            if "a" in layers:
                amp = 0.10 if boss else 0.08
                step = 1 if boss else 1
                for k in range(0, 8, step):
                    m = ch[[0, 1, 2, 1][k % 4]] + (12 if k >= 4 else 0) + 12
                    if kingdom == "censura" and not boss and k % 2:
                        continue  # rigido: solo tiempos fuertes
                    n = int(e8 * SR * (0.6 if cfg["arp"] != "lira" else 1.0))
                    ts = t0 + k * e8 + (swing * e8 if k % 2 else 0)
                    tr.put(ts, note(cfg["arp"], fold(m, 88), n), amp)
            # ---- pad
            if "p" in layers:
                n = int(e8 * 8 * SR * 0.98)
                for i, m in enumerate(ch):
                    tr.put(t0, note(cfg["pad"], m, n) * env(n, 0.12, 0.2), 0.06 if cfg["pad"] != "choir" else 0.07)
            # ---- bateria (patron por reino; el relleno cierra cada frase)
            if "d" in layers:
                dr = cfg["drums"]
                fill = (b % 4 == 3)
                for k in range(8):
                    ts = t0 + k * e8 + (swing * e8 if k % 2 else 0)
                    c = dr["k"][k]
                    if c == "k":
                        tr.kick(ts, 0.40 if boss else 0.36)
                    elif c == "b":
                        tr.bongo(ts, 260 + 30 * (k % 3), 0.26)
                    c = dr["s"][k]
                    if c == "s":
                        tr.snare(ts, 0.30)
                    elif c == "t":
                        tr.tom(ts, 80 + 12 * (k % 3), 0.42)
                    elif c == "c":
                        tr.clack(ts, 0.22)
                    elif c == "b":
                        tr.bongo(ts, 380, 0.22)
                    c = dr["h"][k]
                    if c == "h":
                        tr.hat(ts, 0.06 if not boss else 0.08)
                    elif c == "c":
                        tr.clack(ts, 0.10)
                if fill and boss:
                    for k in (5, 6, 7):
                        tr.snare(t0 + k * e8, 0.26)
                elif fill and kingdom == "pene":
                    for k, f in ((6, 110), (7, 90)):
                        tr.tom(t0 + k * e8, f, 0.40)
                if kingdom == "censura" and b % 2 == 0:
                    tr.put(t0, note("bronze", tonic + 12 + SCALES[scale][root % 7] - 12, int(e8 * 8 * SR * 0.95)), 0.07)
                if b == 0:
                    tr.crash(t0, 0.12 if not boss else 0.18)
        bar0 += nb
    return tr


def finish(out):
    out = out.copy()
    # sin componente continua (no rompe el bucle)
    out -= out.mean()
    for _ in range(8):
        out *= TARGET_RMS / np.sqrt((out ** 2).mean())
        if np.abs(out).max() > PEAK:  # limitador suave solo si hace falta
            out = np.tanh(out / PEAK) * PEAK
    return np.clip(out, -PEAK, PEAK)


def main():
    kings = sys.argv[1:] or list(THEMES)
    for k in kings:
        for kind, prefix in (("e", "explore"), ("b", "boss")):
            tr = render(k, kind)
            out = finish(tr.out)
            pcm = (out * 32767).astype("<i2")
            path = "assets/audio/music/%s_%s.wav" % (prefix, k)
            with wave.open(path, "wb") as f:
                f.setnchannels(1)
                f.setsampwidth(2)
                f.setframerate(SR)
                f.writeframes(pcm.tobytes())
            path = to_ogg(path)
            print(path, "%.1f s" % (len(pcm) / SR), "rms %.3f" % np.sqrt((out ** 2).mean()),
                  "pico %.3f" % np.abs(out).max())


if __name__ == "__main__":
    main()
