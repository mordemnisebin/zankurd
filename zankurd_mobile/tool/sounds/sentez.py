"""ZanKurd efekt sesleri sentezleyicisi (yalnız Python standart kitaplığı).

Kapışma U17 (2026-10-29): `win.mp3` `correct.mp3`'ün, `wildcard.mp3`
`coin.mp3`'ün bayt bayt kopyasıydı; kısa tıklama (`playTick`) için 2 saniyelik
jeton sesi çalınıyordu. Bu betik üç yeni sesi sıfırdan üretir; dışarıdan ses
örneği kullanılmaz, lisans sorunu yoktur.

Kullanım (depo kökünden değil, zankurd_mobile/ içinden):

    python3 tool/sounds/sentez.py /tmp/zk_ses
    for n in tick win wildcard; do
      lame --quiet -b 128 /tmp/zk_ses/$n.wav assets/sounds/$n.mp3
    done

Karakter: sıcak, oyunsu, rahatsız etmeyen — marimba benzeri tonlar (temel +
yumuşak 4. harmonik, üstel sönüm), sert kare dalga yok, tepe −6 dBFS altında.
"""

import math
import random
import struct
import sys
import wave
from pathlib import Path

RATE = 44100


def _env(t, attack, decay):
    if t < attack:
        return t / attack
    return math.exp(-(t - attack) / decay)


def _marimba(freq, dur, amp=1.0, decay=0.22):
    out = []
    n = int(dur * RATE)
    for i in range(n):
        t = i / RATE
        e = _env(t, 0.004, decay)
        s = math.sin(2 * math.pi * freq * t)
        s += 0.25 * math.sin(2 * math.pi * freq * 4 * t) * math.exp(-t / 0.05)
        s += 0.08 * math.sin(2 * math.pi * freq * 2 * t)
        out.append(amp * e * s)
    return out


def _mix(dst, src, at):
    start = int(at * RATE)
    need = start + len(src)
    if need > len(dst):
        dst.extend([0.0] * (need - len(dst)))
    for i, v in enumerate(src):
        dst[start + i] += v
    return dst


def _normalize(buf, peak_db=-6.0):
    peak = max(abs(v) for v in buf) or 1.0
    target = 10 ** (peak_db / 20)
    return [v * target / peak for v in buf]


def _fade_out(buf, ms=12):
    n = int(ms / 1000 * RATE)
    for i in range(min(n, len(buf))):
        buf[-1 - i] *= i / n
    return buf


def tick():
    """≤150 ms yumuşak tahta tıkı: kısa ton + çok kısa gürültü vuruşu."""
    rnd = random.Random(7)
    dur = 0.075
    out = []
    for i in range(int(dur * RATE)):
        t = i / RATE
        tone = math.sin(2 * math.pi * 1650 * t) * math.exp(-t / 0.012)
        tone += 0.35 * math.sin(2 * math.pi * 820 * t) * math.exp(-t / 0.02)
        noise = (rnd.random() * 2 - 1) * math.exp(-t / 0.003) * 0.4
        out.append(tone + noise)
    return _fade_out(_normalize(out, -12.0), 8)


def win():
    """Kazanma: Do majör yükselen arpej (C5 E5 G5) + tutulan C6 + ışıltı."""
    notes = [(523.25, 0.0), (659.25, 0.11), (783.99, 0.22), (1046.5, 0.36)]
    buf = []
    for freq, at in notes[:-1]:
        _mix(buf, _marimba(freq, 0.45, 0.8, 0.18), at)
    last_freq, last_at = notes[-1]
    _mix(buf, _marimba(last_freq, 0.9, 1.0, 0.38), last_at)
    _mix(buf, _marimba(last_freq * 1.5, 0.7, 0.25, 0.3), last_at + 0.04)
    return _fade_out(_normalize(buf, -6.0), 30)


def wildcard():
    """Joker: kısa yükselen süpürme + iki çan vuruşu (E6, B6)."""
    buf = []
    sweep = []
    dur = 0.24
    phase = 0.0
    for i in range(int(dur * RATE)):
        t = i / RATE
        f = 600 + (1400 - 600) * (t / dur) ** 1.4
        phase += 2 * math.pi * f / RATE
        e = math.sin(math.pi * t / dur) ** 2
        sweep.append(0.35 * e * math.sin(phase))
    _mix(buf, sweep, 0.0)
    _mix(buf, _marimba(1318.5, 0.45, 0.8, 0.14), 0.18)
    _mix(buf, _marimba(1975.5, 0.45, 0.6, 0.12), 0.27)
    return _fade_out(_normalize(buf, -7.0), 25)


def _write(path, mono):
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = bytearray()
        for v in mono:
            s = max(-1.0, min(1.0, v))
            iv = int(s * 32767)
            frames += struct.pack('<hh', iv, iv)
        w.writeframes(bytes(frames))


def main():
    out = Path(sys.argv[1] if len(sys.argv) > 1 else '.')
    out.mkdir(parents=True, exist_ok=True)
    for name, fn in (('tick', tick), ('win', win), ('wildcard', wildcard)):
        _write(out / f'{name}.wav', fn())
        print(name, out / f'{name}.wav')


if __name__ == '__main__':
    main()
