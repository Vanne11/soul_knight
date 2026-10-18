"""Convierte un .wav largo (musica, camas de ambiente) a .ogg Vorbis (~q4, mismo canal y frecuencia) y borra el .wav.

Uso: python3 tools/to_ogg.py archivo.wav [...]   (o import to_ogg desde los generadores)
Los efectos cortos se quedan en WAV: solo la musica y las camas largas van en OGG
(sound.gd y ambient_audio.gd ponen el bucle en el AudioStreamOggVorbis).
"""
import os
import subprocess
import sys


def to_ogg(wav: str, quality: int = 4) -> str:
    ogg = os.path.splitext(wav)[0] + ".ogg"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", str(quality), ogg], check=True)
    os.remove(wav)
    return ogg


if __name__ == "__main__":
    for w in sys.argv[1:]:
        print(to_ogg(w))
