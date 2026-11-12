#!/usr/bin/env python3
"""Makes Verbarium's music from recorded instruments, following the document "Kitab Lore Verbarium".

One short theme belongs to the Chronicler, the player. It never changes; the way it is played does, title by title:
  m0 Peasant  Desa       an alto recorder alone, no bass; the theme stops before it comes home. Wind and birds.
  m1 Squire   Kota       G major in 6/8: recorder, folk harp, a frame drum; phrases of five bars that stumble,
                         a turn to minor, home only once. Then the murmur of the town and a distant bell.
  m2 Knight   Kastel     D mixolydian, a slow march: the horn plays the theme, the cellos answer it in minor
                         every time, a low D never stops, the cadence never lands. High violins hint at the King.
  m3 Baron    Kadipaten  A minor: two harpsichord voices chase each other (a canon) over low strings; a brief
                         memory of the recorder from the village. Then an empty hall.
  m4 Count    Marka      B minor, a night watch on the border wall: low strings hold, the solo violin plays the theme
                         and breaks off where the Fog begins, a far horn calls and nothing answers, a side drum walks
                         the wall. Then wind on the battlements.
  m5 Duke     menuju Takhta  E lydian, slow: the theme at half speed on glockenspiel and harp over hanging
                         strings, a low flute; it ends suspended. Crickets.
  m6 King     Takhta     D major: the recorder alone, as in the village; then strings and horn, borrowed minor
                         chords, and the theme comes home for the first time; then the recorder and the wind again.
  battle                 D minor, 120: pizzicato ostinato, timpani, side drum; the horn plays the theme twisted
                         (its notes bent to Phrygian), and the Chronicler's own theme tries to break through.
Every piece is followed by its place alone (wind, town, hall, night) before it plays again: music, then silence
that belongs to the place, as the lore asks.
Effects made here as well: wrong, rise, levelup, fanfare, quill, seal, page, tap, hit, crit, hurt, victory, defeat, and each line's tap and hit (see sfx()). Every sound of the app now comes from this file.

The instruments are samples from two CC0 (public domain) libraries by Versilian Studios, used only to render the
files; nothing of them ships in the app except the rendered music:
  VSCO 2 Community Edition  https://github.com/sgossner/VSCO-2-CE   (flute, string sections, contrabass, horn,
                            harp, solo violin, glockenspiel)
  VCSL                      https://github.com/sgossner/VCSL        (alto recorder, folk harp, harpsichord,
                            frame drum, timpani, rope snare, tubular bells, suspended cymbal)
Clone them (git, ~4 GB together) and point VSCO and VCSL at them, or keep them at ~/sgossner/vsco-2-ce and
~/sgossner/vcsl. Most of their files name the note an octave low (C3 = middle C); Inst(octave=...) corrects that,
measured file by file with a harmonic product spectrum.

Every melody here is written for Verbarium, note by note; none is taken from any soundtrack.
Needs numpy, scipy and ffmpeg (libvorbis). Run from the repository root:
    python3 content/tools/make_music.py              # everything
    python3 content/tools/make_music.py m0 sfx       # some
Writes mobile/android/app/src/main/res/raw/*.ogg.
"""
import glob
import json
import os
import re
import subprocess
import sys

import numpy as np
from scipy.signal import butter, fftconvolve, sosfilt

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', '..', 'mobile', 'android', 'app', 'src', 'main', 'res', 'raw')
VSCO = os.environ.get('VSCO', os.path.expanduser('~/sgossner/vsco-2-ce'))
VCSL = os.environ.get('VCSL', os.path.expanduser('~/sgossner/vcsl'))
rng = np.random.default_rng(1215)
NOTE = {'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E': 4, 'F': 5, 'F#': 6, 'Gb': 6, 'G': 7, 'G#': 8,
        'Ab': 8, 'A': 9, 'A#': 10, 'Bb': 10, 'B': 11}


def midi(s): return 12 * (int(s[-1]) + 1) + NOTE[s[:-1]]
def T(n): return np.arange(n) / SR
def lp(x, fc, o=2): return sosfilt(butter(o, fc, 'low', fs=SR, output='sos'), x, axis=0)
def hp(x, fc, o=2): return sosfilt(butter(o, fc, 'high', fs=SR, output='sos'), x, axis=0)
def bp(x, a, b, o=2): return sosfilt(butter(o, [a, b], 'band', fs=SR, output='sos'), x, axis=0)


def P(s, shift=0):
    """'A4:1 D5:1.5 r:1' -> [(midi or None, beats)]; bars may be marked with |"""
    out = []
    for tok in s.replace('|', ' ').split():
        n, b = tok.split(':')
        out.append((None if n == 'r' else midi(n) + shift, float(b)))
    return out

# ---------------------------------------------------------------------------------------------- samples

_cache = {}


def load(path):
    if path not in _cache:
        r = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-f', 'f32le', '-ac', '2', '-ar', str(SR), '-'],
                           capture_output=True, check=True)
        x = np.frombuffer(r.stdout, np.float32).reshape(-1, 2).astype(np.float64)
        a = np.abs(x).max(axis=1)
        start = max(0, int(np.argmax(a > 0.02 * a.max())) - 64)
        _cache[path] = x[start:] / (a.max() + 1e-9)
    return _cache[path]


class Inst:
    """A sampled instrument: the nearest sample, moved to the pitch wanted by resampling."""

    def __init__(self, folder, octave=1, sustain=True, release=.35, ring=3.0, gain=1.0, attack=.004, only=None):
        self.map = {}
        for p in glob.glob(os.path.join(folder, '*.wav')):
            name = os.path.basename(p)
            if only and not re.search(only, name):
                continue
            m = re.search(r'_([A-G]#?)(-?\d)(?=[_.])', name)
            if m:
                self.map.setdefault(12 * (int(m.group(2)) + 1) + NOTE[m.group(1)] + 12 * octave, []).append(p)
        if not self.map:
            raise SystemExit(f'no samples in {folder}: clone VSCO 2 CE and VCSL (see the top of this file)')
        self.keys = np.array(sorted(self.map))
        self.sustain, self.release, self.ring, self.gain, self.attack = sustain, release, ring, gain, attack

    def note(self, m, dur, vel=.7):
        k = int(self.keys[np.argmin(np.abs(self.keys - m))])
        files = sorted(self.map[k])
        x = load(files[min(len(files) - 1, int(vel * len(files)))])
        ratio = 2 ** ((m - k) / 12)
        keep = (dur + self.release) if self.sustain else (dur + self.ring)
        need = int(keep * SR * ratio) + 2
        if self.sustain and need > len(x):
            x = _extend(x, need)
        x = x[:need]
        idx = np.arange(0, len(x) - 1, ratio)
        i0 = idx.astype(int); fr = (idx - i0)[:, None]
        y = x[i0] * (1 - fr) + x[i0 + 1] * fr
        t = T(len(y))
        env = np.minimum(1, t / self.attack)
        if self.sustain:
            env = env * np.where(t > dur, np.clip(1 - (t - dur) / self.release, 0, 1) ** 1.5, 1)
        else:
            tail = int(.08 * SR)
            if len(env) > tail:
                env[-tail:] *= np.linspace(1, 0, tail)
        return y * env[:, None] * vel * self.gain


def _extend(x, need):
    """lengthens a sustained note by crossfading loops of its steady middle"""
    a, b = int(len(x) * .35), int(len(x) * .85)
    fade = min(int(.12 * SR), (b - a) // 3)
    out = x[:b].copy()
    while len(out) < need:
        seg = x[a:b].copy()
        w = np.linspace(0, 1, fade)[:, None]
        out[-fade:] = out[-fade:] * (1 - w) + seg[:fade] * w
        out = np.concatenate([out, seg[fade:]])
    return out


class Hit:
    """an unpitched (or roughly pitched) one-shot: drums, cymbal, bells"""

    def __init__(self, folder, pattern):
        self.files = sorted(p for p in glob.glob(os.path.join(folder, '*.wav')) if re.search(pattern, os.path.basename(p)))
        if not self.files:
            raise SystemExit(f'no samples for {pattern} in {folder}')

    def hit(self, vel=.7, shift=0.0, length=None):
        x = load(self.files[int(rng.integers(0, len(self.files)))])
        if shift:
            ratio = 2 ** (shift / 12)
            idx = np.arange(0, len(x) - 1, ratio); i0 = idx.astype(int); fr = (idx - i0)[:, None]
            x = x[i0] * (1 - fr) + x[i0 + 1] * fr
        if length:
            x = x[:int(length * SR)].copy()
            tail = min(len(x), int(.1 * SR)); x[-tail:] *= np.linspace(1, 0, tail)[:, None]
        return x * vel


def kit():
    W, S, B, K = f'{VSCO}/Woodwinds', f'{VSCO}/Strings', f'{VSCO}/Brass', f'{VSCO}/Percussion'
    A, C, M, I = (f'{VCSL}/Aerophones/Edge-blown Aerophones', f'{VCSL}/Chordophones', f'{VCSL}/Membranophones/Struck Membranophones',
                  f'{VCSL}/Idiophones/Struck Idiophones')
    return {
        'recorder': Inst(f'{A}/Baroque Alto Recorder/SusVib', release=.3, gain=.9),
        'flute': Inst(f'{W}/Flute/susvib', release=.4),
        'fharp': Inst(f'{C}/Composite Chordophones/Folk Harp', sustain=False, ring=3.5, only='Normal'),
        'harp': Inst(f'{S}/Harp', octave=0, sustain=False, ring=4),
        'violins': Inst(f'{S}/Violin Section/susVib', release=.6, attack=.12),
        'violas': Inst(f'{S}/Viola Section/susvib', release=.6, attack=.12),
        'cellos': Inst(f'{S}/Cello Section/susvib', release=.6, attack=.08),
        'pizz': Inst(f'{S}/Cello Section/pizzT', sustain=False, ring=1.2),
        'bass': Inst(f'{S}/Solo Contrabass/SusVib', release=.7, attack=.1),
        'fiddle': Inst(f'{S}/Solo Violin/Arco Vib', octave=0, release=.35, attack=.03),
        'horn': Inst(f'{B}/F Horn/sus', release=.45, attack=.04),
        'glock': Inst(f'{K}/Glock', octave=0, sustain=False, ring=3),
        'harpsi': Inst(f'{C}/Zithers/Harpsichord, Flemish/Sustains/High', sustain=False, ring=2.2),
        'harpsiL': Inst(f'{C}/Zithers/Harpsichord, Flemish/Sustains/Low', sustain=False, ring=2.2),
        'bells': Inst(f'{I}/Tubular Bells 1', sustain=False, ring=6),
        'frame': Hit(f'{M}/Frame Drum', r'HDrumL_Hit_'),
        'frameS': Hit(f'{M}/Frame Drum', r'HDrumS_Hit_'),
        'timp': Hit(f'{M}/Timpani 1/Hit', r'Timpani1_Hit_v[34]'),
        'timpsoft': Hit(f'{M}/Timpani 1/Hit', r'Timpani1_Hit_v2'),
        'roll': Hit(f'{M}/Timpani 1/Roll', r'Timpani1_Roll'),
        'snare': Hit(f'{M}/Snare Drum, Rope Tension/Hi', r'vl1'),
        'cymbal': Hit(f'{I}/Suspended Cymbal 1', r'susCymb1_cresc_4s'),
        'crash': Hit(f'{I}/Suspended Cymbal 1', r'hit_bell_mf'),
    }

# ---------------------------------------------------------------------------------------------- places (synthesised)


def wind(length, level=1.0):
    n = int(length * SR); t = T(n)
    out = np.zeros((n, 2))
    for c in range(2):
        x = lp(rng.standard_normal(n), 380) * 4 + bp(rng.standard_normal(n), 600, 1400) * .8
        out[:, c] = x * (.55 + .45 * np.sin(2 * np.pi * .045 * t + rng.uniform(0, 6)) * np.sin(2 * np.pi * .013 * t + c))
    return out * level


def bird():
    parts = []
    for _ in range(rng.integers(2, 6)):
        d = rng.uniform(.05, .13); n = int(d * SR); t = T(n)
        f = rng.uniform(2700, 4200) + rng.uniform(-900, 900) * t / d + 160 * np.sin(2 * np.pi * rng.uniform(25, 55) * t)
        parts.append(np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / d) ** 2)
        parts.append(np.zeros(int(rng.uniform(.04, .11) * SR)))
    return np.concatenate(parts)


def crickets(length, fc=4600):
    n = int(length * SR); out = np.zeros(n); tt = rng.uniform(0, 1)
    m = int(.022 * SR); w = np.sin(np.pi * np.arange(m) / m) ** 2 * np.sin(2 * np.pi * fc * np.arange(m) / SR)
    while tt < length - 1:
        for p in range(rng.integers(2, 5)):
            i = int((tt + p * .042) * SR); out[i:i + m] += w
        tt += rng.uniform(.7, 1.3)
    return out


def murmur(length):
    """a town far off: voices as filtered noise that swells and falls"""
    n = int(length * SR); t = T(n); out = np.zeros((n, 2))
    for c in range(2):
        x = bp(rng.standard_normal(n), 250, 1800, 2)
        am = .5 + .5 * lp(np.abs(rng.standard_normal(n)), 3, 1) * 8
        out[:, c] = x * np.clip(am, 0, 1.5) * (.7 + .3 * np.sin(2 * np.pi * .03 * t + c))
    return out


def room(length, low=55):
    """a large empty room: a low hum and air"""
    n = int(length * SR); t = T(n); out = np.zeros((n, 2))
    for c in range(2):
        out[:, c] = lp(rng.standard_normal(n), 220) * 3 + np.sin(2 * np.pi * low * t + c) * .02
    return out


def crackle(length, rate=3.0):
    n = int(length * SR); out = np.zeros(n)
    for _ in range(int(length * rate)):
        i = int(rng.uniform(0, length - .05) * SR); k = int(rng.uniform(.002, .006) * SR)
        out[i:i + k] += rng.standard_normal(k) * rng.uniform(.2, 1)
    return hp(out, 1500)

# ---------------------------------------------------------------------------------------------- mixer


def make_ir(rt):
    n = int(rt * 1.3 * SR); t = T(n); irs = []
    for c in range(2):
        nz = rng.standard_normal(n)
        lo = lp(nz, 3000); hi = nz - lo
        ir = lo * np.exp(-6.9 * t / rt) + .3 * hi * np.exp(-6.9 * t / (rt * .4))
        ir *= 1 - np.exp(-t / .015)
        ir = np.concatenate([np.zeros(int(.025 * SR)), ir])
        irs.append(lp(ir, 8000) / np.sqrt(np.sum(ir ** 2)))
    return irs


class Mix:
    def __init__(self, length):
        self.n = int(length * SR); self.dry = np.zeros((self.n, 2)); self.send = np.zeros(self.n); self.e = {}

    def add(self, sig, start, pan=0., gain=1., send=.3, tag='x'):
        if sig.ndim == 1:
            sig = np.stack([sig, sig], 1)
        i = int(max(0, start) * SR)
        if i >= self.n:
            return
        j = min(self.n, i + len(sig)); x = sig[:j - i] * gain
        l, r = np.cos((pan + 1) * np.pi / 4) * 1.41, np.sin((pan + 1) * np.pi / 4) * 1.41
        self.dry[i:j, 0] += x[:, 0] * min(1, l); self.dry[i:j, 1] += x[:, 1] * min(1, r)
        self.send[i:j] += x.mean(axis=1) * send
        self.e[tag] = self.e.get(tag, 0) + float(np.sum(x * x))

    def render(self, name, rt=2.6, lufs=-18, fade=3.0, fade_in=.05, peak=None):
        """peak: for very short sounds, a peak level in dBFS instead of loudness normalisation"""
        irL, irR = make_ir(rt)
        st = self.dry + np.stack([fftconvolve(self.send, irL)[:self.n], fftconvolve(self.send, irR)[:self.n]], 1)
        st = hp(st, 30)
        fi = int(fade_in * SR); st[:fi] *= np.linspace(0, 1, fi)[:, None]
        fo = int(fade * SR); st[-fo:] *= (np.linspace(1, 0, fo) ** 1.6)[:, None]
        st = st / np.max(np.abs(st)) * .89
        wav = f'/tmp/verbarium-{name}.wav'
        import scipy.io.wavfile as wf
        wf.write(wav, SR, (st * 32767).astype(np.int16))
        if peak is not None:
            af = f'volume={peak + 0.9:.1f}dB'
        else:
            r = subprocess.run(['ffmpeg', '-hide_banner', '-i', wav, '-af', f'loudnorm=I={lufs}:TP=-1.5:LRA=16:print_format=json',
                                '-f', 'null', '-'], capture_output=True, text=True).stderr
            m = json.loads(r[r.rindex('{'):r.rindex('}') + 1])
            af = (f"loudnorm=I={lufs}:TP=-1.5:LRA=16:measured_I={m['input_i']}:measured_TP={m['input_tp']}:"
                  f"measured_LRA={m['input_lra']}:measured_thresh={m['input_thresh']}:offset={m['target_offset']}:linear=true")
        os.makedirs(OUT, exist_ok=True)
        out = f'{OUT}/{name}.ogg'
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-af', af, '-ar', str(SR), '-c:a', 'libvorbis',
                        '-q:a', '2', out], check=True)
        os.remove(wav)
        tot = max(self.e.values())
        print(f'{name}.ogg {self.n / SR:.0f}s {os.path.getsize(out) // 1024} kB  ' +
              ' '.join(f'{k}:{10 * np.log10(v / tot):.0f}' for k, v in sorted(self.e.items())))


def hum(s=.008): return rng.normal(0, s)


def play(mx, inst, notes, start, beat, pan=0., gain=.5, send=.35, vel=.6, leg=1.0, rubato=0.0, tag='mel'):
    """plays a line; rubato stretches each note a little at random (a person breathing, not a machine)"""
    t = start
    for m, b in notes:
        d = b * beat * (1 + rng.uniform(-rubato, rubato))
        if m is not None:
            mx.add(inst.note(m, d * leg, vel * (1 + rng.uniform(-.06, .06))), t + hum(), pan, gain, send, tag)
        t += d
    return t


def chord(mx, inst, notes, start, dur, gain=.12, send=.5, vel=.5, spread=.6, tag='pad'):
    for j, m in enumerate(notes):
        p = -spread + 2 * spread * j / max(1, len(notes) - 1)
        mx.add(inst.note(midi(m) if isinstance(m, str) else m, dur, vel), start + hum(.01), p, gain, send, tag)


def arp(mx, inst, notes, start, step, pattern, gain=.3, send=.4, vel=.5, pan=-.25, tag='arp'):
    for i, k in enumerate(pattern):
        if k is not None:
            m = notes[k]
            mx.add(inst.note(midi(m) if isinstance(m, str) else m, step, vel * (1 if i == 0 else .8)), start + i * step + hum(), pan,
                   gain, send, tag)

# ---------------------------------------------------------------------------------------------- the Chronicler's theme

THEME = "A4:1 D5:1.5 E5:.5 F#5:2 E5:1 D5:1 B4:2"   # stops on the sixth: not home
HOME = "A4:1 D5:3"                                   # the way home, heard in full only at the King
ANSWER = "F#5:1 A5:1.5 G5:.5 F#5:1 E5:1 D5:1 E5:3"   # ends on the second: a question

# ---------------------------------------------------------------------------------------------- pieces


def peasant(k):
    """Desa. The recorder alone, unmeasured; the theme never comes home. The village is louder than the music."""
    beat = 60 / 66
    music = 34
    L = music + 44
    mx = Mix(L)
    mx.add(wind(L, .9), 0, 0, .055, .15, 'place')
    t = rng.uniform(1, 3)
    while t < L - 3:
        mx.add(bird(), t, rng.uniform(-.9, .9), .07, .5, 'place')
        t += rng.uniform(2.5, 7)
    t = play(mx, k['recorder'], P(THEME), 4, beat, pan=.1, gain=.5, vel=.55, rubato=.08, tag='recorder')
    mx.add(k['fharp'].note(midi('D3'), 3, .45), t - 1.6, -.3, .25, .5, 'harp')
    mx.add(k['fharp'].note(midi('A3'), 3, .4), t - 1.5, -.25, .2, .5, 'harp')
    t = play(mx, k['recorder'], P("F#5:1 A5:1.5 B5:.5 A5:1 F#5:1 D5:1 E5:3"), t + 2.5, beat, pan=.1, gain=.5, vel=.5, rubato=.1,
             tag='recorder')
    t = play(mx, k['recorder'], P("A4:1 D5:1.5 E5:.5 F#5:2 E5:1 D5:1 B4:4"), t + 3, beat * 1.08, pan=.1, gain=.48, vel=.5,
             rubato=.1, tag='recorder')
    mx.add(k['fharp'].note(midi('B2'), 4, .4), t - 3.4, -.3, .22, .55, 'harp')
    mx.render('m0', rt=2.4)


def squire(k):
    """Kota. 6/8: five-bar phrases that stumble, a turn to minor; home only once. Then the town."""
    e = .3; bar = 6 * e
    A = P("D5:2 G5:3 A5:1 | B5:4 A5:2 | G5:3 E5:3 | D5:2 E5:1 G5:3 | E5:6")
    B = P("B5:2 D6:3 C6:1 | B5:3 A5:3 | G5:2 A5:1 B5:3 | G5:6")
    chA = [['G2', 'D3', 'G3', 'B3'], ['E2', 'B2', 'E3', 'G3'], ['C3', 'G3', 'C4', 'E4'], ['D3', 'A3', 'D4', 'F#4'], ['E2', 'B2', 'E3', 'G3']]
    chB = [['G2', 'D3', 'G3', 'B3'], ['D3', 'A3', 'D4', 'F#4'], ['C3', 'G3', 'C4', 'E4'], ['G2', 'D3', 'G3', 'B3']]
    plan = [('intro', [chA[0], chA[1]])] + [('A', chA), ('B', chB), ('A2', chA), ('B2', chB)] + [('end', [chB[0]])]
    bars = sum(len(c) for _, c in plan)
    music = bars * bar + 3
    L = music + 34
    mx = Mix(L)
    mx.add(murmur(L), 0, 0, .014, .2, 'place')
    mx.add(wind(L, .5), 0, 0, .01, .1, 'place')
    t = 1.0
    for name, chs in plan:
        t0 = t
        for i, c in enumerate(chs):
            arp(mx, k['fharp'], c, t, e, [0, 2, 3, 1, 2, 3], gain=.32, vel=.5)
            mx.add(k['pizz'].note(midi(c[0]) + 12, .5, .45), t + hum(.004), .2, .3, .25, 'bass')
            if name != 'intro':
                mx.add(k['frame'].hit(.5), t + hum(.004), .05, .32, .15, 'drum')
                mx.add(k['frameS'].hit(.28), t + 3 * e + hum(.004), .05, .3, .15, 'drum')
            t += bar
        if name == 'A':
            play(mx, k['recorder'], A, t0, e, pan=.12, gain=.48, vel=.6, leg=.97, tag='lead')
        elif name == 'B':
            play(mx, k['recorder'], B, t0, e, pan=.12, gain=.48, vel=.62, leg=.97, tag='lead')
        elif name == 'A2':
            play(mx, k['fiddle'], A, t0, e, pan=-.1, gain=.6, vel=.55, leg=.98, tag='fiddle')
        elif name == 'B2':
            play(mx, k['recorder'], B, t0, e, pan=.12, gain=.42, vel=.6, leg=.97, tag='lead')
            play(mx, k['fiddle'], P("B4:2 D5:3 C5:1 | B4:3 A4:3 | G4:2 A4:1 B4:3 | G4:6"), t0, e, pan=-.15, gain=.3, vel=.5, tag='fiddle')
    mx.add(k['fharp'].note(midi('G3'), 3, .5), t, -.2, .3, .5, 'arp')
    for j, d in enumerate([0, 7, 14]):
        mx.add(k['bells'].note(midi('G3') + d, 6, .35), music + 6 + j * 9, .5, .2, .7, 'bell')
    mx.render('m1', rt=2.0)


def knight(k):
    """Kastel. The horn carries the theme; the cellos answer in minor; a low D never stops; no cadence lands."""
    beat = 60 / 84; bar = 4 * beat
    horn1 = P("A3:1 D4:1.5 E4:.5 F#4:2 E4:1 D4:1 B3:2 r:3")              # 3 bars
    shadow = P("A2:1 D3:1.5 E3:.5 F3:2 E3:1 D3:2")                          # 2 bars, minor
    horn2 = P("F#4:1 A4:1.5 G4:.5 F#4:1 E4:1 C4:1 E4:3 r:3")                # mixolydian, ends open
    pads = {'D': ['D4', 'F#4', 'A4'], 'C': ['C4', 'E4', 'G4'], 'G': ['D4', 'G4', 'B4'], 'Dm': ['D4', 'F4', 'A4'], 'A': ['C#4', 'E4', 'A4']}
    form = [('intro', ['D', 'C']), ('h1', ['D', 'C', 'G']), ('sh', ['Dm', 'Dm']), ('h1', ['D', 'C', 'G']), ('sh', ['Dm', 'Dm']),
            ('h2', ['D', 'C', 'A']), ('sh', ['Dm', 'Dm']), ('hint', ['D', 'D'])]
    bars = sum(len(c) for _, c in form)
    music = bars * bar + 4
    L = music + 34
    mx = Mix(L)
    mx.add(wind(L, .8), 0, 0, .03, .3, 'place')
    t = 1.0
    for name, chs in form:
        t0 = t
        for c in chs:
            mx.add(k['bass'].note(midi('D2'), bar, .55), t, .25, .22, .3, 'pedal')       # the weight that never lifts
            chord(mx, k['violins'] if name != 'sh' else k['violas'], pads[c], t, bar, gain=.07 if name != 'intro' else .05)
            mx.add(k['timpsoft'].hit(.55, shift=0), t + hum(.004), 0, .3, .3, 'timp')
            mx.add(k['timpsoft'].hit(.35, shift=0), t + 2 * beat + hum(.004), 0, .26, .3, 'timp')
            for b in (1, 3):
                mx.add(k['snare'].hit(.22), t + b * beat + hum(.004), .2, .22, .25, 'snare')
            t += bar
        if name == 'h1':
            play(mx, k['horn'], horn1, t0, beat, pan=.15, gain=.5, vel=.62, leg=.96, tag='horn')
        elif name == 'h2':
            play(mx, k['horn'], horn2, t0, beat, pan=.15, gain=.5, vel=.7, leg=.96, tag='horn')
        elif name == 'sh':
            play(mx, k['cellos'], shadow, t0, beat, pan=-.25, gain=.42, vel=.6, leg=1.0, tag='shadow')
        elif name == 'hint':
            # the King's homecoming, begun high and quiet, and left unfinished
            play(mx, k['violins'], P("A5:2 D6:3 r:3"), t0, beat, pan=-.2, gain=.32, vel=.45, tag='hint')
    mx.add(k['roll'].hit(.4, length=3), t - bar, 0, .3, .4, 'timp')
    mx.render('m2', rt=2.8)


def baron(k):
    """Kadipaten. Two harpsichord voices chase each other over low strings; a short memory of the village."""
    beat = 60 / 72; bar = 4 * beat
    v1 = P("E4:1 A4:1.5 B4:.5 C5:2 B4:1 A4:1 F4:2 | E4:1 A4:1.5 B4:.5 C5:1 D5:1 E5:2 B4:2")
    v2 = P("r:2 E3:1 A3:1.5 B3:.5 C4:2 B3:1 A3:1 F3:2 | E3:1 A3:1.5 B3:.5 C4:1 D4:1 E4:2")
    low = [('A2', 'E3'), ('F2', 'C3'), ('D3', 'A3'), ('E2', 'B2')]
    music = 0
    L = 6 * 4 * bar + 40
    mx = Mix(L)
    mx.add(room(L), 0, 0, .025, .4, 'place')
    mx.add(crackle(L, 2.0), 0, -.4, .04, .3, 'place')
    t = 1.0
    for rep in range(3):
        for i, (a, b) in enumerate(low):
            chord(mx, k['cellos'], [a, b], t + i * bar, bar, gain=.11, vel=.45, spread=.3)
        play(mx, k['harpsi'], v1, t, beat, pan=.3, gain=.36, vel=.55, tag='voice1')
        play(mx, k['harpsiL'], v2, t, beat, pan=-.3, gain=.32, vel=.5, tag='voice2')
        if rep == 1:
            # the village, remembered for a moment, far away
            play(mx, k['recorder'], P("G5:1 C6:1.5 D6:.5 E6:3"), t + 4 * bar - 6 * beat, beat, pan=.5, gain=.18, send=.9, vel=.4, tag='memory')
        t += 4 * bar
    music = t
    chord(mx, k['cellos'], ['E2', 'B2'], t, 2 * bar, gain=.12, vel=.45)
    mx.add(k['harpsiL'].note(midi('E3'), 2, .5), t, -.3, .3, .5, 'voice2')
    mx.add(k['harpsi'].note(midi('G#4'), 2, .5), t + .05, .3, .3, .5, 'voice1')
    mx.render('m3', rt=3.0)


def count(k):
    """Marka. B minor, a night watch on the border wall: low strings hold, the solo violin plays the theme and breaks
    off where the Fog begins, a far horn calls and nothing answers, a side drum walks the wall. Then wind."""
    beat = 60 / 60; bar = 4 * beat
    pads = [['B2', 'F#3', 'D4'], ['G2', 'D3', 'B3'], ['E2', 'B2', 'G3'], ['F#2', 'C#3', 'A#3']] * 3
    music = len(pads) * 2 * bar + 6
    L = music + 38
    mx = Mix(L)
    mx.add(wind(L, 1.0), 0, 0, .05, .15, 'place')
    t = 1.0
    for ch in pads:
        chord(mx, k['cellos'], ch[:2], t, 2 * bar, gain=.11, vel=.45, spread=.3)
        chord(mx, k['violas'], ch[2:], t, 2 * bar, gain=.07, vel=.4)
        mx.add(k['bass'].note(midi(ch[0]) - 12, 2 * bar, .45), t, .2, .11, .3, 'low')
        # the watch walks the wall, far off
        for j, d in enumerate((0, .5, 1.0, 1.75)):
            mx.add(k['snare'].hit(.18 if j < 3 else .26), t + 4 * beat + d * beat, .55, .07, .85, 'drum')
        t += 2 * bar
    # the theme in B minor on the solo violin, twice; the second time the Fog takes its end
    whole = P("F#4:1 B4:1.5 C#5:.5 D5:2 C#5:1 B4:1 G4:2 r:7")
    broken = P("F#4:1 B4:1.5 C#5:.5 D5:3 r:10")
    t = play(mx, k['fiddle'], whole, 1 + 2 * bar, beat, pan=-.1, gain=.42, vel=.5, rubato=.07, tag='violin')
    t = play(mx, k['fiddle'], broken, t, beat * 1.05, pan=-.1, gain=.4, vel=.45, rubato=.09, tag='violin')
    # a horn from the next tower; nothing answers
    play(mx, k['horn'], P("F#3:1 B3:2.5 A3:.5 F#3:3"), 1 + 12 * bar, beat, pan=.6, gain=.24, send=.9, vel=.5, tag='horn')
    play(mx, k['fiddle'], P("D5:1 C#5:1 B4:2 A#4:6"), 1 + 18 * bar, beat * 1.1, pan=-.1, gain=.36, vel=.42, rubato=.06, tag='violin')
    end = 1 + len(pads) * 2 * bar
    chord(mx, k['cellos'], ['F#2', 'C#3'], end, 3 * bar, gain=.1, vel=.4, spread=.3)
    mx.add(k['fiddle'].note(midi('A#4'), 3 * bar, .35), end + .2, -.1, .2, .7, 'violin')
    mx.render('m4', rt=3.2)


def duke(k):
    """Toward the Throne. The theme at half speed on glockenspiel and harp over strings that hang; crickets."""
    beat = 60 / 56
    slow = P("B4:2 E5:3 F#5:1 G#5:4 F#5:2 E5:2 C#5:4")         # the theme in E, twice as long
    flute = P("G#4:1.5 B4:2 A#4:.75 G#4:1.5 F#4:1.5 E4:1.5 F#4:4")  # lydian A#, ends on the second
    pads = [(['E3', 'B3', 'G#4'], 4), (['F#3', 'C#4', 'A#4'], 4), (['E3', 'B3', 'G#4'], 4), (['C#3', 'G#3', 'E4'], 4),
            (['E3', 'B3', 'G#4'], 4), (['F#3', 'C#4', 'A#4'], 4), (['A2', 'E3', 'C#4'], 4), (['F#3', 'C#4', 'A#4'], 6)]
    music = sum(b for _, b in pads) * beat + 4
    L = music + 36
    mx = Mix(L)
    mx.add(crickets(L, 4600), 0, -.6, .022, .3, 'place'); mx.add(crickets(L, 4900), 0, .6, .018, .3, 'place')
    mx.add(wind(L, .4), 0, 0, .008, .1, 'place')
    t = 1.0
    for notes, b in pads:
        chord(mx, k['violins'], notes, t, b * beat, gain=.07, vel=.4)
        mx.add(k['bass'].note(midi(notes[0]) - 12, b * beat, .4), t, .2, .1, .4, 'low')
        t += b * beat
    play(mx, k['glock'], slow, 3, beat, pan=.3, gain=.45, send=.6, vel=.5, rubato=.05, tag='glock')
    play(mx, k['harp'], P("B3:2 E4:3 F#4:1 G#4:4 F#4:2 E4:2 C#4:4"), 3, beat, pan=-.3, gain=.3, send=.55, vel=.5, rubato=.05, tag='harp')
    play(mx, k['flute'], flute, 3 + 20 * beat, beat, pan=0, gain=.32, send=.5, vel=.45, rubato=.06, tag='flute')
    mx.render('m5', rt=3.8)


def king(k):
    """Takhta. The recorder alone, as in the village; then the court; the theme comes home at last; then the village."""
    beat = 60 / 64; bar = 4 * beat
    L = 4 + 6 * bar + 8 * bar + 4 * bar + 6 * bar + 30
    mx = Mix(L)
    village = wind(L, .8)
    fade = np.ones(len(village)); a, b = int(10 * SR), int((10 + 3 * bar) * SR)
    c, d = int((4 + 6 * bar + 8 * bar + 2 * bar) * SR), int((4 + 6 * bar + 12 * bar) * SR)
    fade[a:b] = np.linspace(1, .15, b - a); fade[b:c] = .15; fade[c:d] = np.linspace(.15, 1, d - c)
    mx.add(village * fade[:, None], 0, 0, .045, .15, 'place')
    # 1. alone, as in the village
    t = play(mx, k['recorder'], P(THEME), 3, beat, pan=.1, gain=.48, vel=.5, rubato=.08, tag='recorder')
    t = 4 + 6 * bar
    # 2. the court: strings, then the horn with the theme; borrowed chords make the glory bitter
    court = [['D3', 'A3', 'D4', 'F#4'], ['B2', 'F#3', 'B3', 'D4'], ['G2', 'D3', 'G3', 'B3'], ['A2', 'E3', 'A3', 'C#4'],
             ['G2', 'D3', 'G3', 'Bb3'], ['D3', 'A3', 'D4', 'F#4'], ['Bb2', 'F3', 'Bb3', 'D4'], ['A2', 'E3', 'A3', 'C#4']]
    for i, ch in enumerate(court):
        chord(mx, k['cellos'], ch[:2], t + i * bar, bar, gain=.12, vel=.55, spread=.3)
        chord(mx, k['violas'], ch[2:], t + i * bar, bar, gain=.09, vel=.5)
        mx.add(k['bass'].note(midi(ch[0]) - 12, bar, .5), t + i * bar, .2, .12, .3, 'low')
    play(mx, k['horn'], P("A3:1 D4:1.5 E4:.5 F#4:2 E4:1 D4:1 B3:2 r:7"), t, beat, pan=.15, gain=.48, vel=.62, tag='horn')
    play(mx, k['violins'], P("r:16 F#5:1 A5:1.5 G5:.5 F#5:1 E5:1 D5:1 E5:3 r:7"), t, beat, pan=-.15, gain=.35, vel=.55, tag='violins')
    mx.add(k['cymbal'].hit(.3), t + 8 * bar - 4, 0, .25, .5, 'cym')
    t += 8 * bar
    # 3. home, for the first time on the whole road
    for i, ch in enumerate([['D3', 'A3', 'D4', 'F#4'], ['G2', 'D3', 'G3', 'B3'], ['A2', 'E3', 'A3', 'C#4'], ['D3', 'A3', 'D4', 'F#4']]):
        chord(mx, k['cellos'], ch[:2], t + i * bar, bar, gain=.14, vel=.65, spread=.3)
        chord(mx, k['violas'], ch[2:], t + i * bar, bar, gain=.11, vel=.6)
        chord(mx, k['violins'], [midi(n) + 12 for n in ch[1:]], t + i * bar, bar, gain=.06, vel=.55)
        mx.add(k['bass'].note(midi(ch[0]) - 12, bar, .6), t + i * bar, .2, .14, .3, 'low')
    home = P("A3:1 D4:1.5 E4:.5 F#4:2 E4:1 D4:1 B3:2 A3:1 D4:6")
    play(mx, k['horn'], home, t, beat, pan=.15, gain=.52, vel=.75, tag='horn')
    play(mx, k['violins'], [(m + 24 if m else None, b) for m, b in home], t, beat, pan=-.15, gain=.25, vel=.6, tag='violins')
    mx.add(k['roll'].hit(.5, length=3.5), t + 9 * beat - 3.5, 0, .3, .4, 'timp')
    mx.add(k['timp'].hit(.7), t + 10 * beat, 0, .4, .4, 'timp')
    mx.add(k['crash'].hit(.4), t + 10 * beat, 0, .2, .6, 'cym')
    for j, m in enumerate(['D6', 'F#6', 'A6', 'D7']):
        mx.add(k['glock'].note(midi(m), 1.5, .45), t + 10 * beat + j * .12, .3, .35, .7, 'glock')
    t += 4 * bar
    # 4. the village again: the recorder, now coming home quietly
    play(mx, k['recorder'], P("A4:1 D5:1.5 E5:.5 F#5:2 E5:1 D5:1 B4:2 A4:1 D5:5"), t + 2, beat * 1.1, pan=.1, gain=.42, vel=.45, rubato=.08,
         tag='recorder')
    mx.render('m6', rt=3.4)


def battle(k):
    """A fight: the shadow's ostinato against the Chronicler's theme. The horn plays the theme bent to Phrygian."""
    beat = .5; bar = 4 * beat
    roots = ['D3', 'Bb2', 'G2', 'A2']
    twisted = P("A3:1 D4:1 Eb4:.5 F4:1.5 Eb4:1 D4:1 Bb3:2")
    pads = {'D3': ['D4', 'F4', 'A4'], 'Bb2': ['D4', 'F4', 'Bb4'], 'G2': ['D4', 'G4', 'Bb4'], 'A2': ['C#4', 'E4', 'A4']}
    L = 24 * bar + 2.5
    mx = Mix(L)
    for i in range(24):
        r = roots[(i // 2) % 4] if i < 20 else roots[i % 4]
        t0 = i * bar
        for s, off in enumerate([0, 0, 7, 0, 12, 0, 7, 0]):
            mx.add(k['pizz'].note(midi(r) + off, .2, .7 if s % 2 == 0 else .5), t0 + s * beat / 2 + hum(.003), -.3, .3, .2, 'ost')
        mx.add(k['timp'].hit(.6), t0, 0, .4, .25, 'timp')
        mx.add(k['timpsoft'].hit(.45), t0 + 2 * beat, 0, .35, .25, 'timp')
        for b in (1, 3):
            mx.add(k['snare'].hit(.3), t0 + b * beat, .2, .25, .2, 'snare')
        if i >= 4:
            chord(mx, k['violins'], pads[r], t0, bar, gain=.06 if i < 12 else .09, vel=.55)
    for start in (4, 8, 12):
        play(mx, k['horn'], twisted, start * bar, beat, pan=.15, gain=.48, vel=.7, tag='horn')
    play(mx, k['cellos'], [(m - 12 if m else None, b) for m, b in twisted], 12 * bar, beat, pan=-.2, gain=.3, vel=.6, tag='horn')
    # the Chronicler's own theme tries to break through, a little more each time
    play(mx, k['fiddle'], P("A4:1 D5:1 E5:.5 F#5:1.5"), 16 * bar, beat, pan=-.1, gain=.6, vel=.65, tag='hero')
    play(mx, k['fiddle'], P("A4:1 D5:1.5 E5:.5 F#5:2 E5:1 D5:2"), 18 * bar, beat, pan=-.1, gain=.62, vel=.7, tag='hero')
    play(mx, k['horn'], P("A3:1 D4:1.5 E4:.5 F#4:2 E4:1 D4:1 B3:1"), 20 * bar, beat, pan=.15, gain=.5, vel=.75, tag='horn')
    mx.add(k['cymbal'].hit(.25), 16 * bar - 4, 0, .25, .4, 'cym')
    mx.render('battle', rt=2.0, lufs=-16, fade=1.5)

# ---------------------------------------------------------------------------------------------- effects


def sfx(k):
    def one(name, build, L, rt=2.2, lufs=-18, peak=None):
        mx = Mix(L); build(mx); mx.render(name, rt=rt, lufs=lufs, fade=min(.4, L / 4), peak=peak)

    def wrong(mx):
        # not a punishment: a half step down, then back up
        mx.add(k['fharp'].note(midi('E4'), .3, .45), 0, 0, .5, .4, 'a'); mx.add(k['fharp'].note(midi('D#4'), .3, .4), .14, 0, .45, .4, 'a')
        mx.add(k['fharp'].note(midi('E4'), .4, .3), .34, 0, .3, .5, 'a')

    def rise(mx):
        for j, m in enumerate(['D6', 'E6', 'F#6', 'A6', 'B6', 'D7', 'A6', 'F#6', 'D7']):
            mx.add(k['glock'].note(midi(m), .4, .4), j * .085 + rng.uniform(0, .02), rng.uniform(-.7, .7), .3, .7, 'g')

    def levelup(mx):
        for j, m in enumerate(['D4', 'E4', 'F#4', 'A4', 'B4', 'D5', 'E5', 'F#5', 'A5']):
            mx.add(k['harp'].note(midi(m), 1.2, .5), j * .05, -.5 + j / 8, .35, .5, 'h')

    def fanfare(mx):
        # the Chronicler's theme, home in full, as a call
        play(mx, k['horn'], P("A3:.5 D4:.75 E4:.25 F#4:1 A3:.5 D4:2"), 0, .4, pan=.1, gain=.55, vel=.8, tag='horn')
        mx.add(k['timp'].hit(.7), 0, 0, .4, .3, 't'); mx.add(k['timp'].hit(.8), 1.2, 0, .45, .3, 't')
        chord(mx, k['violas'], ['D4', 'F#4', 'A4'], 1.2, 1.4, gain=.12, vel=.6)
        mx.add(k['crash'].hit(.35), 1.2, 0, .2, .5, 'c')

    one('wrong', wrong, 1.6); one('rise', rise, 2.4, 2.8); one('levelup', levelup, 2.8); one('fanfare', fanfare, 4.0, 2.4)

    # the desk and the ceremonies, all from the same samples (they used to be synthesised by make_audio.py)
    def quill(mx):
        # a right answer while learning: the pen touches the page, one soft harp note of the theme's home
        mx.add(hp(k['frameS'].hit(.12, shift=12, length=.08), 2500), 0, -.2, .4, .05, 'q')
        mx.add(k['fharp'].note(midi('D6'), .25, .3), .02, .2, .3, .35, 'q')

    def seal(mx):
        # wax pressed on a page: a muffled low drum and a low bell under it
        mx.add(lp(k['timpsoft'].hit(.7, length=.6), 900), 0, 0, .6, .2, 's')
        mx.add(k['bells'].note(midi('D3'), 1.6, .25), .03, 0, .25, .55, 's')

    def page(mx):
        # a page turned: brushed skin, quick and dry
        x = k['frameS'].hit(.3, shift=-7, length=.3)
        mx.add(bp(x, 900, 6000), 0, -.3, .5, .15, 'p')
        mx.add(bp(rng.standard_normal((int(.22 * SR), 2)), 2000, 7000) * np.linspace(0, 1, int(.22 * SR))[:, None] ** .5
               * np.linspace(1, 0, int(.22 * SR))[:, None] ** 2 * .12, .02, .3, .4, .15, 'p')

    def tap(mx):
        mx.add(k['frameS'].hit(.22, shift=5, length=.2), 0, 0, .45, .05, 't')

    def hit(mx):
        mx.add(k['frame'].hit(.55, length=.35), 0, 0, .55, .1, 'h')
        mx.add(k['pizz'].note(midi('D3'), .2, .5), 0, 0, .3, .2, 'h')

    def crit(mx):
        # a critical blow: a bright spark over the line's own hit (App.sfx plays both)
        for j, m in enumerate(['A6', 'D7', 'F#7']):
            mx.add(k['glock'].note(midi(m), .3, .5), j * .03, -.3 + j * .3, .35, .6, 'c')
        mx.add(k['crash'].hit(.25), 0, 0, .2, .5, 'c')

    def hurt(mx):
        # a blow taken: a dull drum and two cello notes a half step apart
        mx.add(k['timpsoft'].hit(.6, shift=-3, length=.5), 0, 0, .55, .2, 'u')
        mx.add(k['pizz'].note(midi('C#3'), .2, .6), .02, -.2, .35, .2, 'u'); mx.add(k['pizz'].note(midi('C3'), .3, .5), .14, .2, .3, .2, 'u')

    def victory(mx):
        # the theme's first phrase on horn, answered by the harp, landing home on D
        play(mx, k['horn'], P("A3:.5 D4:.75 E4:.25 F#4:1.5"), 0, .38, pan=.1, gain=.5, vel=.75, tag='horn')
        mx.add(k['timp'].hit(.6), 0, 0, .35, .3, 't')
        for j, m in enumerate(['D4', 'F#4', 'A4', 'D5', 'F#5']):
            mx.add(k['harp'].note(midi(m), 1.4, .45), 1.1 + j * .07, -.4 + j * .2, .35, .55, 'h')
        chord(mx, k['violas'], ['D4', 'F#4', 'A4'], 1.1, 1.6, gain=.1, vel=.5)

    def defeat(mx):
        # not a punishment: the theme sinks a step and rests, unresolved, on a soft roll
        play(mx, k['cellos'], P("F#3:1 E3:1 D3:.75 C#3:1.5"), 0, .42, pan=-.1, gain=.4, vel=.5, tag='cello')
        mx.add(k['timpsoft'].hit(.35, length=1.2), .9, 0, .3, .4, 't')
        chord(mx, k['violas'], ['A3', 'C#4', 'E4'], 1.3, 1.6, gain=.07, vel=.4)

    one('quill', quill, .6, rt=1.0, peak=-8); one('seal', seal, 1.8, rt=1.8, peak=-4); one('page', page, .5, rt=.8, peak=-10)
    one('tap', tap, .3, rt=.6, peak=-14); one('hit', hit, .8, rt=1.2, peak=-3); one('crit', crit, 1.2, rt=1.6, peak=-6)
    one('hurt', hurt, .9, rt=1.2, peak=-4); one('victory', victory, 3.6, rt=2.4); one('defeat', defeat, 3.4, rt=2.6)

    # each line's tap and hit; '_p' is the Peasant, then lines 0-3 (Blade, Scout, Scribe, Sentinel); 'x' = from tier 3
    taps = {
        'p': lambda mx: mx.add(k['frameS'].hit(.25, length=.25), 0, 0, .5, .05, 't'),
        '0': lambda mx: mx.add(k['glock'].note(midi('A6'), .05, .25), 0, 0, .35, .1, 't'),
        '1': lambda mx: mx.add(k['fharp'].note(midi('E6'), .05, .3), 0, 0, .45, .1, 't'),
        '2': lambda mx: mx.add(k['harpsi'].note(midi('D6'), .05, .35), 0, 0, .45, .1, 't'),
        '3': lambda mx: mx.add(k['frame'].hit(.3, length=.3), 0, 0, .55, .05, 't'),
    }
    for key, f in taps.items():
        one(f'tap_{key}', f, .35, rt=.8, peak=-14)

    def hit_line(line, rich):
        def build(mx):
            if line == 'p':     # a stick on wood
                mx.add(k['frameS'].hit(.6, shift=4, length=.4), 0, 0, .6, .1, 'h')
            elif line == '0':   # clean steel
                mx.add(bp(rng.standard_normal(int(.18 * SR)), 2500, 9000) * np.linspace(1, 0, int(.18 * SR)) ** 2 * .6, 0, -.2, .6, .2, 'h')
                mx.add(k['glock'].note(midi('E7'), .1, .4), .02, .1, .3, .4, 'h')
                if rich: mx.add(k['bells'].note(midi('A4'), 1.5, .35), .03, 0, .25, .6, 'h')
            elif line == '1':   # string and wind
                mx.add(k['pizz'].note(midi('A3'), .2, .7), 0, -.3, .5, .2, 'h')
                mx.add(bp(rng.standard_normal(int(.25 * SR)), 600, 3000) * np.linspace(1, 0, int(.25 * SR)) * .4, .03, .3, .5, .2, 'h')
                if rich: mx.add(k['fharp'].note(midi('E6'), .3, .4), .05, .4, .3, .5, 'h')
            elif line == '2':   # ink and a little magic
                for j, m in enumerate(['A5', 'E6', 'A6'] if not rich else ['A5', 'E6', 'A6', 'C#7', 'E7']):
                    mx.add(k['glock'].note(midi(m), .2, .35), j * .035, -.4 + j * .2, .25, .6, 'h')
            else:               # wood, stone, heavy armour
                mx.add(k['timp'].hit(.7, shift=5, length=.5), 0, 0, .55, .2, 'h')
                mx.add(k['frame'].hit(.5, length=.3), 0, 0, .4, .1, 'h')
                if rich: mx.add(k['bells'].note(midi('D3'), 1.5, .4), .02, 0, .2, .6, 'h')
        return build

    for line in ['p', '0', '1', '2', '3']:
        one(f'hit_{line}', hit_line(line, False), .9, rt=1.4, peak=-3)
        if line != 'p':
            one(f'hitx_{line}', hit_line(line, True), 1.6, rt=1.8, peak=-3)


if __name__ == '__main__':
    jobs = {'m0': peasant, 'm1': squire, 'm2': knight, 'm3': baron, 'm4': count, 'm5': duke, 'm6': king, 'battle': battle, 'sfx': sfx}
    k = kit()
    for name in (sys.argv[1:] or jobs):
        jobs[name](k)
