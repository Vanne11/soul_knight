"""Banda sonora chiptune generada con Lyria 3.5 (Gemini API) -> assets/audio/music/*.ogg

Uso (desde la raiz del proyecto):
  python3 tools/gen_music_lyria.py list                  lista las pistas y su prompt
  python3 tools/gen_music_lyria.py gen [pista ...]       llama a Lyria (salta las que ya tienen mp3); ~2-3 min y ~0,08 USD cada una
  python3 tools/gen_music_lyria.py playlist              copia mp3 con nombres ordenados + banda_sonora.m3u (Videos)
  python3 tools/gen_music_lyria.py convert [pista ...]   mp3 -> ogg (recorta silencios + fundido de bucle)

Clave en ~/.kaggle/gemini_key. Los mp3 originales van a ORIG_DIRS (fuera del repo).
Presupuesto: MAX_CALLS llamadas en total (contador en ORIG_DIRS[0]/_llamadas.txt).
El prompt SIEMPRE abre con PREFIX y cierra con SUFFIX (Nico lo aprobo asi: si se cambia el orden deja de sonar chiptune).
Los jefes llevan 3 pistas con el MISMO tema (misma tonalidad y motivo) y distinta ira: p1 amenazante,
p2 mas rapida y tensa, p3 furiosa. Se cambia de una a otra al cambiar de fase (enemy_boss.gd)."""
import base64
import json
import os
import subprocess
import sys
import threading
import urllib.request
import urllib.error
from concurrent.futures import ThreadPoolExecutor

ORIG_DIRS = [
    "/home/nick/Escritorio/Proyectos/soul_knight/.claude/arte_fuente/musica_lyria/",
    "/home/nick/Vídeos/Rogue Reproductive/musica_lyria/banda_sonora/",
]
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "music") + "/"
KEY_FILE = os.path.expanduser("~/.kaggle/gemini_key")
URL = "https://generativelanguage.googleapis.com/v1beta/models/lyria-3.5:generateContent"
MAX_CALLS = 65
WORKERS = 4
XFADE = 2.0  # s de fundido de bucle

PREFIX = ("Genre: CHIPTUNE. 8-bit / 16-bit video game soundtrack made ONLY with retro console sound chips "
          "(NES 2A03, SNES SPC700, Game Boy): square waves, pulse waves, triangle bass, noise-channel drums, "
          "fast arpeggios. Absolutely NO real instruments, NO piano, NO strings, NO guitar, NO orchestra, NO vocals. "
          "It must sound like a classic SNES game cartridge.")
SUFFIX = "Loop-friendly. Remember: pure chiptune, sound chip only."
SUFFIX_ONESHOT = "Ends cleanly on a final chord, no loop. Remember: pure chiptune, sound chip only."

# (nombre de archivo sin extension) -> (texto, bucle)
TRACKS: dict[str, tuple[str, bool]] = {}


def add(name, body, loop=True):
    TRACKS[name] = (body, loop)


# ---------------------------------------------------------------- A) exploracion por reino
add("explore_selva", "Playful chiptune exploration theme for 'La Selva Publica', a jungle of hairy humor: key C mixolydian, "
    "116 BPM, bouncy marimba-like short pulse lead, plucky square arpeggios, triangle bass walking on the beats, "
    "noise-channel bongo drums. Cheeky, light, adventurous.")
add("explore_penelandia", "Chiptune exploration theme for 'Penelandia', a proud macho kingdom with a mock-heroic Greek flavor: "
    "key D dorian, 100 BPM, brass-like pulse-wave fanfare lead, triangle lyre arpeggios, stomping triangle bass, "
    "noise-channel timpani toms. Pompous, swaggering, funny.")
add("explore_vulvania", "Chiptune waltz-like theme for 'Vulvania', an elegant pink queendom: key F lydian, 92 BPM, "
    "bell-like pulse-wave lead melody, sparkly chip arpeggios, triangle bass on beats 1 and 4, soft noise-channel heartbeat drums. "
    "Progression I-V-vi-IV-I-V-ii-V.")
add("explore_perineo", "Chiptune exploration theme for 'El Perineo', a tense bureaucratic border zone full of forms and stamps: "
    "key A harmonic minor, 124 BPM, nasal narrow-pulse lead like a kazoo, plucked pulse arpeggios, driving square bass, "
    "noise-channel typewriter clacks and rubber-stamp hits. Nervous office comedy.")
add("explore_prostata", "Chiptune exploration theme for 'La Prostata', an awkward hospital waiting room where nobody talks: "
    "key G dorian, very slow 66 BPM, lazy elevator-music melody on a breathy pulse wave imitating a saxophone thread, "
    "soft triangle arpeggios, sparse brush-like noise hats. Uncomfortably polite silence, dry humor.")
add("explore_utero", "Chiptune exploration theme for 'El Utero', a warm red womb-like level that follows the four phases of the menstrual cycle: "
    "key Eb major, 84 BPM, soft pulse-wave lead, watery bubbling chip arpeggios, a slow triangle heartbeat bass pulse, "
    "gentle noise-channel pulse. Warm, pulsing, cozy with a hint of cramps.")
add("explore_arcoiria", "Chiptune exploration theme for 'Arcoiria', a joyful rainbow pride parade: "
    "key D ionian (major), 126 BPM, bright brass-like pulse lead, bell-like chip accents, marimba-style short pulse arpeggios, "
    "bouncy square bass, noise-channel bongos and cymbals. Festive, proud, colorful.")
add("explore_palacio", "Chiptune exploration theme for 'El Palacio de la Censura', a cold rigid palace of prudishness: "
    "key E phrygian, 84 BPM, stiff square-wave lead, sparse bronze-bell-like chip hits on the strong beats, "
    "slow solemn pulse-wave choir pad, rigid marching noise drums. Cold, strict, ridiculous solemnity.")
add("explore_voz", "Chiptune exploration theme for 'Las Tierras de la Voz', a kingdom where the Silence was freed and people can speak again: "
    "key G major, 88 BPM, warm and hopeful, soft chip choir made of layered triangle and pulse waves, gentle bell-like pulse melody, "
    "flowing arpeggios, soft triangle bass, light noise-channel brush drums. Tender, hopeful, relieved.")
add("explore_paz", "Chiptune exploration theme for a peaceful crossing through liberated kingdoms after the final victory: "
    "key C major, 100 BPM, calm and celebratory, relaxed pulse-wave lead, gentle sparkling arpeggios, round triangle bass, "
    "very soft noise-channel shaker. Serene, quietly proud, a victory stroll.")

# ---------------------------------------------------------------- B) pantallas
add("menu", "Chiptune title-screen theme for 'Rogue Reproductive', a cheeky satirical sex-education roguelike: "
    "key C major, 120 BPM, bright catchy pulse-wave lead melody, bouncy arpeggios, driving triangle bass, "
    "noise-channel drums. Mischievous, heroic, memorable.")
add("intro", "Chiptune story-intro theme: a narrator tells how the Great Censure covered the world in gray: "
    "key A minor, 80 BPM, mysterious and gently ominous at first, soft arpeggios on pulse waves, slow triangle bass, "
    "sparse noise ticks, a small hopeful lead melody appearing near the end.")
add("victoria", "Short chiptune victory jingle, 15 to 25 seconds: key C major, 132 BPM, triumphant pulse-wave fanfare, "
    "sparkling arpeggio run, triangle bass, noise cymbal crash, resolves on a big final chord.", loop=False)
add("derrota", "Short comic chiptune game-over jingle, 8 to 15 seconds: key D minor, 70 BPM, sad descending pulse-wave melody "
    "with a pitch-bending wah-wah slide, slow triangle bass, a single noise-channel thud, ends on a deflated low chord. Dark humor.", loop=False)
add("final_verdadero", "Chiptune true-ending theme: the whole world speaks and the colors return: key D major, 90 BPM, "
    "starts tender with soft bell-like pulse notes and gentle arpeggios, then grows into a triumphant emotional finale "
    "with a soaring pulse-wave lead, layered chip choir made of square and triangle waves, full triangle bass and noise drums.")

# ---------------------------------------------------------------- C) jefes (3 fases, mismo tema)
PHASES = {
    1: "PHASE 1 of 3, threatening: measured and menacing, sparse layers, tension building, BPM {b1}.",
    2: "PHASE 2 of 3, faster and tense: the same theme played faster at BPM {b2}, denser arpeggios, harder driving drums.",
    3: "PHASE 3 of 3, furious and frenetic: the same theme at breakneck BPM {b3}, relentless 16th-note arpeggios, "
       "constant double-time noise drums, all channels at full intensity.",
}


def boss(id_, intro, theme, bpms, extra3=""):
    for n in (1, 2, 3):
        ph = PHASES[n].format(b1=bpms[0], b2=bpms[1], b3=bpms[2])
        if n == 3 and extra3:
            ph += " " + extra3
        add("boss_%s_p%d" % (id_, n), "Chiptune boss battle theme for %s. %s %s" % (intro, theme, ph))


boss("cera", "'Dona Cera Caliente', a sadistic beautician who waxes everything bald",
     "Key A phrygian. Same motif in all phases: a dripping descending hot-wax pulse-wave arpeggio answered by a sizzling noise-channel hiss, "
     "triangle bass stomping on the beat.", (128, 148, 172))
add("boss_afeitadora_p1", "")  # placeholder, se reescribe abajo
del TRACKS["boss_afeitadora_p1"]
boss("afeitadora", "'La Afeitadora Electrica', a perfectionist electric razor with zero margin of error",
     "Key E minor. Same motif in all phases: a buzzing electric-razor pulse-wave lead with fast vibrato repeating on one pitch, "
     "then a sharp stepwise run, square bass on the off-beats.", (132, 152, 176))
boss("testiculo_primordial", "'El Testiculo Primordial', a car-sized patriarch with one giant eye who attacks with unmet expectations",
     "Key D phrygian dominant. Same motif in all phases: a heavy brass-like pulse-wave fanfare of disappointed father energy, "
     "stomping low triangle bass, noise-channel timpani.", (120, 144, 168))
boss("don_sildenafil", "'Don Sildenafil', a pompous gentleman who has been standing upright for four hours",
     "Key Bb major turning stern. Same motif in all phases: a stiff upright marching pulse-wave fanfare, held rigid long notes "
     "followed by a fast mumbling legal-disclaimer chip run, bouncing square bass.", (124, 146, 170))
boss("reina_ovaria", "'Su Majestad Ovaria II', a purple-caped queen who only holds audiences once a month",
     "Key F# harmonic minor. Same motif in all phases: a regal bell-like pulse-wave lead playing a grand rising royal phrase, "
     "sparkling arpeggios, triangle bass on beats 1 and 3.", (116, 140, 164))
boss("diu_cosmico", "'El DIU Cosmico', a cold device that orbits space without asking for anything",
     "Key B minor. Same motif in all phases: a slow orbiting circular pulse-wave arpeggio that keeps looping, cold bell-like blips, "
     "deep triangle bass drone.", (112, 138, 166))
boss("regla", "'Dona Regla', a two-meter ruler who always arrives punctually when nobody expects her",
     "Key C minor. Same motif in all phases: a strictly metronomic ticking noise-channel clock rhythm, "
     "a precise stepwise pulse-wave motif counting measures, deep red triangle bass pulse.", (118, 142, 168))
boss("aduanero", "'El Aduanero Hormonal', a giant rubber-stamp customs officer demanding form 27-B in triplicate",
     "Key G minor. Same motif in all phases: a stern marching pulse-wave motif punctuated by heavy noise-channel STAMP hits on the downbeat, "
     "square bass in steady quarter notes.", (120, 144, 170))
boss("prostata", "'Dona Ventanilla', a walking service window with curlers, cat-eye glasses and chewing gum, always missing one paper",
     "Key D dorian. Same motif in all phases: a sour elevator-muzak melody on a pulse-wave, a ticket-machine ding bell blip every two bars, "
     "typewriter clack noise percussion, bouncy square bass.", (118, 142, 168))
boss("glandula", "'La Glandula Callada', a silent gland in a tense waiting room that never speaks and grows each phase",
     "Key G dorian. Same motif in all phases: a sparse slow three-note pulse-wave motif surrounded by uncomfortable silence, "
     "low swelling triangle bass, a ticking noise-channel clock; the music itself grows heavier each phase.", (84, 110, 144))
boss("don_chequeo", "'Don Chequeo', an obsessive doctor of waiting rooms and routine check-ups",
     "Key A dorian. Same motif in all phases: a steady heart-monitor beep on a high pulse-wave over a nervous clinical melody, "
     "square bass pulse like a pulse reading, noise-channel clipboard clicks.", (122, 146, 172))
boss("destine", "'La Censura que Destine', a force that drains the colors out of the rainbow",
     "Key D mixolydian. Same motif in all phases: a bright rainbow-like rising pulse-wave arpeggio of the parade theme that keeps getting "
     "drained, detuned and bitten by gray noise-channel static, steady square bass.", (126, 150, 176))
boss("hoja_de_parra", "'Su Pudorosidad, la Hoja de Parra', the final boss: a prudish fig leaf queen who covers everything",
     "Key E phrygian. Same motif in all phases: a pompous grand fanfare on pulse waves with bronze-bell-like chip hits, "
     "a stern 'cover yourself!' call-and-response phrase, heavy triangle bass, solemn noise drums.", (112, 140, 166),
     extra3="This is 'La Parra Entera', the giant thorny vine second form: the most epic, grandest and most intense final battle of the whole game, "
            "huge layered chip choir of pulse waves, wild thorny vine-like arpeggios, thundering drums.")
boss("algoritmo", "'El Algoritmo Moderador', a cold cloud moderation AI that detects the infraction of existing",
     "Key F# minor. Same motif in all phases: cold digital bit-crushed pulse-wave motif with glitchy stuttering repeats and data-burst noise, "
     "robotic square bass sequence, mechanical noise drums.", (126, 150, 178))

# la pista final = intro + body + sufijo
SPECIAL_SUFFIX = {n: SUFFIX_ONESHOT for n, (_, loop) in TRACKS.items() if not loop}


def prompt(name):
    body, loop = TRACKS[name]
    return "%s %s %s" % (PREFIX, body, SUFFIX if loop else SUFFIX_ONESHOT)


# ---------------------------------------------------------------- llamadas
_lock = threading.Lock()


def _counter():
    return os.path.join(ORIG_DIRS[0], "_llamadas.txt")


def _bump() -> int:
    with _lock:
        n = 0
        if os.path.exists(_counter()):
            n = int(open(_counter()).read().strip() or 0)
        if n >= MAX_CALLS:
            raise SystemExit("presupuesto agotado: %d llamadas" % n)
        n += 1
        open(_counter(), "w").write(str(n))
        return n


def call_lyria(text: str) -> bytes:
    key = open(KEY_FILE).read().strip()
    body = json.dumps({"contents": [{"parts": [{"text": text}]}]}).encode()
    req = urllib.request.Request(URL, data=body, headers={"x-goog-api-key": key, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=600) as r:
        data = json.load(r)
    for part in data["candidates"][0]["content"]["parts"]:
        inl = part.get("inlineData") or part.get("inline_data")
        if inl and "audio" in inl.get("mimeType", inl.get("mime_type", "")):
            return base64.b64decode(inl["data"])
    raise RuntimeError("sin audio en la respuesta: %s" % json.dumps(data)[:300])


STOP = threading.Event()


def gen_one(name):
    if STOP.is_set():
        return
    path = ORIG_DIRS[0] + name + ".mp3"
    if os.path.exists(path):
        print("[ya existe]", name, flush=True)
        return
    n = _bump()
    print("[llamada %d] %s" % (n, name), flush=True)
    try:
        mp3 = call_lyria(prompt(name))
    except urllib.error.HTTPError as e:
        print("[ERROR HTTP %d] %s: %s" % (e.code, name, e.read()[:300]), flush=True)
        if e.code in (402, 429):
            STOP.set()  # cuota: detenerse
        return
    except Exception as e:  # noqa: BLE001
        print("[ERROR] %s: %s" % (name, e), flush=True)
        return
    os.makedirs(ORIG_DIRS[0], exist_ok=True)
    open(ORIG_DIRS[0] + name + ".mp3", "wb").write(mp3)
    playlist()
    print("[ok] %s %d KB" % (name, len(mp3) // 1024), flush=True)


BOSS_NAMES = {
    "cera": "dona_cera", "afeitadora": "afeitadora", "testiculo_primordial": "testiculo_primordial",
    "don_sildenafil": "don_sildenafil", "reina_ovaria": "reina_ovaria", "diu_cosmico": "diu_cosmico",
    "regla": "dona_regla", "aduanero": "aduanero", "prostata": "dona_ventanilla", "glandula": "glandula_callada",
    "don_chequeo": "don_chequeo", "destine": "censura_destine", "hoja_de_parra": "hoja_de_parra", "algoritmo": "algoritmo",
}


def nice_names():
    """nombre de pista -> nombre ordenado para la lista de reproduccion de Nico (01_menu, 10_explora_selva, 30_jefe_..._fase1)."""
    out = {}
    for i, n in enumerate(["menu", "intro", "victoria", "derrota", "final_verdadero"]):
        out[n] = "%02d_%s" % (i + 1, n)
    explores = [n for n in TRACKS if n.startswith("explore_")]
    for i, n in enumerate(explores):
        out[n] = "%02d_explora_%s" % (10 + i, n[len("explore_"):])
    k = 30
    for n in TRACKS:
        if n.startswith("boss_"):
            id_, ph = n[len("boss_"):].rsplit("_p", 1)
            out[n] = "%02d_jefe_%s_fase%s" % (k, BOSS_NAMES.get(id_, id_), ph)
            k += 1
    return out


def playlist():
    """Copia los mp3 con nombres ordenados a ORIG_DIRS[1] y escribe banda_sonora.m3u (rutas relativas)."""
    nn = nice_names()
    os.makedirs(ORIG_DIRS[1], exist_ok=True)
    lines = ["#EXTM3U"]
    for n, nice in sorted(nn.items(), key=lambda kv: kv[1]):
        src = ORIG_DIRS[0] + n + ".mp3"
        if os.path.exists(src):
            open(ORIG_DIRS[1] + nice + ".mp3", "wb").write(open(src, "rb").read())
            lines.append(nice + ".mp3")
    open(ORIG_DIRS[1] + "banda_sonora.m3u", "w").write("\n".join(lines) + "\n")


def duration(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path],
                         capture_output=True, text=True).stdout.strip()
    return float(out)


def convert_one(name):
    src = ORIG_DIRS[0] + name + ".mp3"
    if not os.path.exists(src):
        print("[falta mp3]", name)
        return
    loop = TRACKS[name][1]
    tmp = "/tmp/_lyria_%s.wav" % name
    # estereo 44,1 kHz y recorte de silencios de inicio y fin
    trim = ("silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.05,"
            "areverse,silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.05,areverse")
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", src, "-ac", "2", "-ar", "44100", "-af", trim, tmp], check=True)
    d = duration(tmp)
    out = OUT_DIR + name + ".ogg"
    if loop:
        x = min(XFADE, d / 4)
        # a[x : L-x] + (cola con fundido de salida mezclada con la cabeza con fundido de entrada): al volver a empezar no hay corte
        fg = ("[0:a]atrim=start=%f:end=%f,asetpts=PTS-STARTPTS[mid];"
              "[0:a]atrim=start=%f:end=%f,asetpts=PTS-STARTPTS[tail];"
              "[0:a]atrim=start=0:end=%f,asetpts=PTS-STARTPTS[head];"
              "[tail][head]acrossfade=d=%f:c1=tri:c2=tri[xf];[mid][xf]concat=n=2:v=0:a=1[o]") % (x, d - x, d - x, d, x, x)
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", tmp, "-filter_complex", fg, "-map", "[o]",
                        "-c:a", "libvorbis", "-q:a", "5", out], check=True)
    else:
        fo = "afade=t=out:st=%f:d=0.5" % max(0, d - 0.5)
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", tmp, "-af", fo, "-c:a", "libvorbis", "-q:a", "5", out], check=True)
    os.remove(tmp)
    print("[ogg] %s %.1f s" % (name, duration(out)))


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    names = sys.argv[2:] or list(TRACKS)
    if cmd == "list":
        for n in names:
            print(n, "| loop" if TRACKS[n][1] else "| una vez", "\n   ", prompt(n))
    elif cmd == "gen":
        os.makedirs(ORIG_DIRS[0], exist_ok=True)
        with ThreadPoolExecutor(WORKERS) as ex:
            list(ex.map(gen_one, names))
    elif cmd == "playlist":
        playlist()
    elif cmd == "convert":
        for n in names:
            convert_one(n)


if __name__ == "__main__":
    main()
