#!/usr/bin/env python3
"""Makes Verbarium's music and a few effects from scratch (no samples, so nothing to license).

One original piece for each title, all in a gentle fantasy-folk mood, growing fuller as the titles rise:
  m0 Hutan Pagi       Peasant  D major, 3/4: harp and flute, birds in the trees
  m1 Perjalanan       Squire   G major, 6/8: flute, harp and a frame drum, on the road
  m2 Benteng          Knight   G mixolydian, a slow march: horn, strings, timpani and a side drum
  m3 Kenangan Lampau  Baron    A minor: piano, then strings and celesta
  m4 Malam Bintang    Duke     E dorian: celesta, harp and flute under the stars, crickets
  m5 Takhta           King     D major, slow and wide: strings, horn, a soft choir and timpani
  battle              fights   D minor, 120 BPM: string ostinato, horn and timpani
Effects: wrong (a soft falling pluck), rise (a shimmer, for a trial passed), levelup (a harp run), fanfare
(a coronation call). The other effects come from make_audio.py.

Every melody is written here, note by note; none is taken from any soundtrack. Moods may be inspired by
others; tunes may not be copied.

Needs numpy, scipy and ffmpeg (libvorbis). Run from the repository root:
    python3 content/tools/make_music.py            # everything
    python3 content/tools/make_music.py m2 sfx     # some
Writes mobile/android/app/src/main/res/raw/*.ogg (played by MainActivity.kt).
"""
import json, os, subprocess, sys
import numpy as np
from scipy.signal import fftconvolve, butter, sosfilt
from scipy.io import wavfile

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'mobile', 'android', 'app', 'src', 'main', 'res', 'raw')
rng = np.random.default_rng(2026)
NOTE = {'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E': 4, 'F': 5, 'F#': 6,
        'Gb': 6, 'G': 7, 'G#': 8, 'Ab': 8, 'A': 9, 'A#': 10, 'Bb': 10, 'B': 11}


def midi(s): return 12 * (int(s[-1]) + 1) + NOTE[s[:-1]]
def hz(s): return 440.0 * 2 ** ((midi(s) - 69) / 12)
def hzm(m): return 440.0 * 2 ** ((m - 69) / 12)
def T(n): return np.arange(n) / SR
def lp(x, fc, o=2): return sosfilt(butter(o, fc, 'low', fs=SR, output='sos'), x)
def hp(x, fc, o=2): return sosfilt(butter(o, fc, 'high', fs=SR, output='sos'), x)
def bp(x, a, b, o=2): return sosfilt(butter(o, [a, b], 'band', fs=SR, output='sos'), x)
def hum(s=0.006): return rng.normal(0, s)


def P(s):
    out = []
    for tok in s.replace('|', ' ').split():
        n, b = tok.split(':')
        out.append((None if n == 'r' else n, float(b)))
    return out

# ---------------------------------------------------------------- instruments


def harp(f, dur, vel=.7):
    n = int((dur + 0.9) * SR); t = T(n); out = np.zeros(n)
    base = 0.7 + f / 350
    for k in range(1, 11):
        fk = k * f * np.sqrt(1 + 0.00015 * k * k)
        if fk > 15000: break
        a = abs(np.sin(np.pi * k * 0.27)) / k ** 1.15 * vel ** (0.3 * (k - 1))
        out += a * np.sin(2 * np.pi * fk * t + rng.uniform(0, 6.3)) * np.exp(-base * (1 + 0.55 * (k - 1)) * t)
    out *= np.minimum(1, t / 0.002)
    out *= np.where(t > dur, np.exp(-(t - dur) * 7), 1)
    return out * vel


def piano(f, dur, vel=.6):
    dur = min(dur, 6.0)
    n = int((dur + 0.5) * SR); t = T(n); out = np.zeros(n)
    s = f / 261.6
    for k in range(1, 15):
        fk = k * f * np.sqrt(1 + 0.0004 * k * k)
        if fk > 14000: break
        a = 1 / k ** 1.2 * vel ** (0.25 * (k - 1))
        d1 = (2.0 + 0.6 * k) * s ** 0.5
        d2 = (0.25 + 0.08 * k) * s ** 0.7
        env = 0.55 * np.exp(-d1 * t) + 0.45 * np.exp(-d2 * t)
        ph = rng.uniform(0, 6.3)
        out += a * env * 0.5 * (np.sin(2 * np.pi * fk * t + ph) + np.sin(2 * np.pi * fk * 1.0006 * t + ph + .5))
    out += lp(rng.standard_normal(n), 2500) * np.exp(-t / 0.004) * 0.12 * vel
    out *= np.minimum(1, t / 0.0015)
    out *= np.where(t > dur, np.exp(-(t - dur) * 9), 1)
    return out * vel


def celesta(f, dur, vel=.6):
    n = int((max(dur, .3) + 1.8) * SR); t = T(n); out = np.zeros(n)
    sc = (f / 880) ** 0.5
    for r, a, d in [(1, 1, 1.1), (2, .28, 2.2), (3.01, .12, 3.5), (4.12, .07, 5), (5.3, .04, 7), (7.1, .05, 14)]:
        if f * r < 16000:
            out += a * np.sin(2 * np.pi * f * r * t + rng.uniform(0, 6.3)) * np.exp(-d * sc * t)
    out *= np.minimum(1, t / 0.001)
    out *= np.where(t > dur + .6, np.exp(-(t - dur - .6) * 4), 1)
    return out * vel


def flute(f, dur, vel=.6):
    n = int((dur + 0.25) * SR); t = T(n)
    vd = 0.0055 * np.clip((t - 0.3) / 0.6, 0, 1)
    vib = 1 + vd * np.sin(2 * np.pi * 5.1 * t + rng.uniform(0, 6.3))
    scoop = 1 - 0.012 * np.exp(-t / 0.05)
    ph = 2 * np.pi * f * np.cumsum(vib * scoop) / SR
    tone = np.sin(ph) + .32 * np.sin(2 * ph + .3) + .11 * np.sin(3 * ph + 1) + .04 * np.sin(4 * ph)
    br = bp(rng.standard_normal(n), f * .9, min(f * 5, 16000))
    att = 1 - np.exp(-t / 0.035)
    swell = 1 + .1 * np.sin(np.pi * np.clip(t / max(dur, .1), 0, 1))
    rel = np.where(t > dur, np.exp(-(t - dur) / 0.06), 1)
    env = att * swell * rel * (1 + .03 * np.sin(2 * np.pi * 5.1 * t))
    return (tone * .8 + br * (0.06 + 0.25 * np.exp(-t / 0.04))) * env * vel


def strings(f, dur, vel=.5, bright=2600, att=.45, rel=.8, voices=3, vibd=.0018):
    n = int((dur + rel) * SR); t = T(n); out = np.zeros(n)
    K = int(max(1, min(16, 7000 / f)))
    for _ in range(voices):
        fv = f * 2 ** (rng.uniform(-7, 7) / 1200)
        vib = 1 + vibd * np.sin(2 * np.pi * rng.uniform(4.6, 5.8) * t + rng.uniform(0, 6.3))
        ph = 2 * np.pi * fv * np.cumsum(vib) / SR + rng.uniform(0, 6.3)
        for k in range(1, K + 1):
            out += np.sin(k * ph) / k
    out = lp(out / voices, bright)
    a = np.clip(t / att, 0, 1); a = a * a * (3 - 2 * a)
    r = np.where(t > dur, np.clip(1 - (t - dur) / rel, 0, 1), 1)
    return out * a * r * vel


def horn(f, dur, vel=.7):
    n = int((dur + .2) * SR); t = T(n); out = np.zeros(n)
    K = int(min(18, 9000 / f))
    vd = .004 * np.clip((t - .25) / .5, 0, 1)
    ph = 2 * np.pi * f * np.cumsum(1 + vd * np.sin(2 * np.pi * 5 * t)) / SR
    br = 1.2 + 2.5 * vel + 3 * np.exp(-t / .12) * (1 - np.exp(-t / .02))
    for k in range(1, K + 1):
        out += np.sin(k * ph) / k * np.exp(-(k - 1) / br)
    env = (1 - np.exp(-t / .03)) * np.where(t > dur, np.exp(-(t - dur) / .05), 1)
    return lp(out, 4500) * env * vel


def timp(f, vel=.8, L=2.2):
    n = int(L * SR); t = T(n)
    ph = 2 * np.pi * np.cumsum(f * (1 + .03 * np.exp(-t / .06))) / SR
    out = sum(a * np.sin(r * ph) * np.exp(-d * t)
              for r, a, d in [(1, 1, 1.3), (1.5, .5, 2.2), (1.99, .35, 2.8), (2.44, .2, 3.6), (2.9, .12, 4.5)])
    out = out + lp(rng.standard_normal(n), 900) * np.exp(-t / .025) * .6
    return out * np.minimum(1, t / .002) * vel


def choir(f, dur, vel=.5, vowel='a'):
    """a soft sung 'ah' (or 'oo'): detuned voices through vowel formants"""
    n = int((dur + 1.0) * SR); t = T(n); src = np.zeros(n)
    for _ in range(4):
        fv = f * 2 ** (rng.uniform(-10, 10) / 1200)
        vib = 1 + .004 * np.sin(2 * np.pi * rng.uniform(4.8, 5.6) * t + rng.uniform(0, 6.3))
        ph = 2 * np.pi * fv * np.cumsum(vib) / SR
        K = int(min(30, 6000 / f))
        for k in range(1, K + 1):
            src += np.sin(k * ph) / k
    forms = [(700, 1220, 2600), (1.0, .5, .25)] if vowel == 'a' else [(320, 800, 2400), (1.0, .3, .1)]
    out = sum(g * bp(src, fc * .85, fc * 1.15) for fc, g in zip(*forms))
    a = np.clip(t / .7, 0, 1); a = a * a * (3 - 2 * a)
    r = np.where(t > dur, np.clip(1 - (t - dur) / 1.0, 0, 1), 1)
    return out * a * r * vel


def snare(vel=.5):
    n = int(.35 * SR); t = T(n)
    x = bp(rng.standard_normal(n), 1500, 7000) * np.exp(-t / .07) + np.sin(2 * np.pi * 190 * t) * np.exp(-t / .04) * .6
    return x * vel


def drum(vel=.6, f=95):
    n = int(.5 * SR); t = T(n)
    ph = 2 * np.pi * np.cumsum(f * (1 + 1.2 * np.exp(-t / .015))) / SR
    return (np.sin(ph) * np.exp(-t / .11) + lp(rng.standard_normal(n), 1500) * np.exp(-t / .015) * .4) * vel


def cymbal(L=2.5, vel=.4, swell=False):
    n = int(L * SR); t = T(n)
    x = hp(rng.standard_normal(n), 5000, 2)
    e = np.exp(-t / .6) if not swell else (t / L) ** 3
    return x * e * vel

# ---------------------------------------------------------------- ambience


def wind(length, level=1.0):
    n = int(length * SR); t = T(n)
    x = lp(rng.standard_normal(n), 380, 2) * 4 + bp(rng.standard_normal(n), 600, 1400) * .8
    lfo = .55 + .45 * np.sin(2 * np.pi * .045 * t + rng.uniform(0, 6)) * np.sin(2 * np.pi * .013 * t + 1)
    return x * lfo * level


def bird():
    parts = []
    for _ in range(rng.integers(2, 6)):
        d = rng.uniform(.05, .13); n = int(d * SR); t = T(n)
        f0 = rng.uniform(2700, 4200); sw = rng.uniform(-900, 900)
        f = f0 + sw * t / d + 160 * np.sin(2 * np.pi * rng.uniform(25, 55) * t)
        parts.append(np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / d) ** 2)
        parts.append(np.zeros(int(rng.uniform(.04, .11) * SR)))
    return np.concatenate(parts)


def cricket(length, fc=4600):
    n = int(length * SR); out = np.zeros(n); tt = rng.uniform(0, 1)
    m = int(.022 * SR); w = np.sin(np.pi * np.arange(m) / m) ** 2 * np.sin(2 * np.pi * fc * np.arange(m) / SR)
    while tt < length - 1:
        for p in range(rng.integers(2, 5)):
            i = int((tt + p * .042) * SR); out[i:i + m] += w
        tt += rng.uniform(.7, 1.3)
    return out * (.6 + .4 * np.sin(2 * np.pi * .03 * T(n) + rng.uniform(0, 6)))

# ---------------------------------------------------------------- mixer


def make_ir(rt):
    n = int(rt * 1.3 * SR); t = T(n); irs = []
    for c in range(2):
        nz = rng.standard_normal(n)
        lo = lp(nz, 3000); hi = nz - lo
        ir = lo * np.exp(-6.9 * t / rt) + .35 * hi * np.exp(-6.9 * t / (rt * .4))
        ir *= 1 - np.exp(-t / .012)
        ir = np.concatenate([np.zeros(int(.022 * SR)), ir])
        ir /= np.sqrt(np.sum(ir ** 2))
        for d, g in [(.009, .3), (.015, .22), (.023, .18), (.031, .13)]:
            ir[int((d + .0017 * c) * SR)] += g
        ir = lp(ir, 9000)
        irs.append(ir / np.sqrt(np.sum(ir ** 2)))
    return irs


class Mix:
    def __init__(s, length):
        s.n = int(length * SR); s.L = np.zeros(s.n); s.R = np.zeros(s.n); s.S = np.zeros(s.n); s.e = {}

    def add(s, sig, start, pan=0., gain=1., send=.3, tag='x'):
        i = int(max(0, start) * SR)
        if i >= s.n: return
        j = min(s.n, i + len(sig)); x = sig[:j - i] * gain
        th = (pan + 1) * np.pi / 4
        s.L[i:j] += x * np.cos(th); s.R[i:j] += x * np.sin(th); s.S[i:j] += x * send
        s.e[tag] = s.e.get(tag, 0) + float(np.sum(x * x))

    def render(s, name, rt=2.8, wet=1.0, lufs=-18, fade=3.5):
        irL, irR = make_ir(rt)
        L = s.L + wet * fftconvolve(s.S, irL)[:s.n]
        R = s.R + wet * fftconvolve(s.S, irR)[:s.n]
        st = np.stack([hp(L, 30), hp(R, 30)], 1)
        fi = int(.05 * SR); st[:fi] *= np.linspace(0, 1, fi)[:, None]
        fo = int(fade * SR); st[-fo:] *= (np.linspace(1, 0, fo) ** 1.6)[:, None]
        st = st / np.max(np.abs(st)) * .89
        wav = f'/tmp/verbarium-{name}.wav'
        wavfile.write(wav, SR, (st * 32767).astype(np.int16))
        r = subprocess.run(['ffmpeg', '-hide_banner', '-i', wav, '-af', f'loudnorm=I={lufs}:TP=-1.5:LRA=14:print_format=json',
                            '-f', 'null', '-'], capture_output=True, text=True).stderr
        m = json.loads(r[r.rindex('{'):r.rindex('}') + 1])
        af = (f"loudnorm=I={lufs}:TP=-1.5:LRA=14:measured_I={m['input_i']}:measured_TP={m['input_tp']}:"
              f"measured_LRA={m['input_lra']}:measured_thresh={m['input_thresh']}:offset={m['target_offset']}:linear=true")
        os.makedirs(OUT, exist_ok=True)
        out = f'{OUT}/{name}.ogg'
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-af', af, '-ar', '44100',
                        '-c:a', 'libvorbis', '-q:a', '2', out], check=True)
        os.remove(wav)
        print(f'{name}.ogg {os.path.getsize(out) // 1024} kB', end='  ')
        tot = max(s.e.values())
        print(name, f'{s.n / SR:.0f}s', ' '.join(f'{k}:{10 * np.log10(v / tot):.1f}' for k, v in sorted(s.e.items())))

# ---------------------------------------------------------------- helpers


def mel(mx, inst, notes, start, beat, pan=0., gain=.5, send=.35, vel=.65, leg=1.0, shift=0, tag='mel', **kw):
    t = start
    for nn, bb in notes:
        if nn:
            mx.add(inst(hz(nn) * 2 ** shift, bb * beat * leg, vel * (1 + rng.uniform(-.07, .07)), **kw),
                   t + hum(), pan, gain, send, tag)
        t += bb * beat
    return t


def arp(mx, inst, voicing, pattern, start, step, bar_end, pan=0., gain=.35, send=.35, vel=.55, tag='arp'):
    for i, idx in enumerate(pattern):
        if idx is None: continue
        t = start + i * step
        v = vel * (1.0 if i == 0 else .78) * (1 + rng.uniform(-.1, .1))
        mx.add(inst(hz(voicing[idx]), max(.1, bar_end - t), v), t + hum(), pan, gain, send, tag)


def pad(mx, notes, start, dur, gain=.08, send=.5, spread=.55, tag='pad', **kw):
    for j, nn in enumerate(notes):
        p = -spread + 2 * spread * j / max(1, len(notes) - 1)
        mx.add(strings(hz(nn), dur, **kw), start, p, gain, send, tag)


def roll(mx, inst, notes, start, dur, gap=.06, pan=0., gain=.35, send=.45, vel=.6, tag='arp'):
    for j, nn in enumerate(notes):
        mx.add(inst(hz(nn), dur - j * gap, vel), start + j * gap, pan + .1 * (j - len(notes) / 2) / len(notes), gain, send, tag)


def ambience_birds(mx, length, gain=.035):
    t = rng.uniform(1, 4)
    while t < length - 3:
        mx.add(bird(), t, rng.uniform(-.9, .9), gain, .6, 'amb')
        t += rng.uniform(3, 9)


def ambience_wind(mx, length, gain=.02):
    mx.add(wind(length), 0, -.7, gain, .2, 'amb'); mx.add(wind(length), 0, .7, gain, .2, 'amb')

# ================================================================ pieces


def hutan_pagi():
    """Morning forest. D major, 3/4, harp and flute."""
    b = 60 / 80; bar = 3 * b
    V = {'D': ['D3', 'A3', 'D4', 'F#4'], 'A/C#': ['C#3', 'A3', 'C#4', 'E4'], 'Bm': ['B2', 'F#3', 'B3', 'D4'],
         'G': ['G2', 'D3', 'G3', 'B3'], 'A': ['A2', 'E3', 'A3', 'C#4']}
    PD = {'D': ['A3', 'D4', 'F#4'], 'A/C#': ['A3', 'C#4', 'E4'], 'Bm': ['B3', 'D4', 'F#4'],
          'G': ['B3', 'D4', 'G4'], 'A': ['A3', 'C#4', 'E4']}
    BS = {'D': 'D3', 'A/C#': 'C#3', 'Bm': 'B2', 'G': 'G2', 'A': 'A2'}
    mA = P("F#5:1.5 E5:.5 D5:1 | E5:1 C#5:1 A4:1 | B4:1.5 C#5:.5 D5:1 | B4:3 | A4:1 D5:1 F#5:1 |"
           " G5:1.5 F#5:.5 E5:1 | E5:1.5 F#5:.5 E5:1 | C#5:2 A4:1")
    mB = P("D5:1 F#5:1 B5:1 | A5:1.5 G5:.5 D5:1 | F#5:1 A5:1 D6:1 | C#6:1.5 B5:.5 A5:1 | B5:1 A5:1 F#5:1 |"
           " G5:1 E5:1 D5:1 | E5:1.5 C#5:.5 E5:1 | D5:3")
    chA = ['D', 'A/C#', 'Bm', 'G', 'D', 'G', 'A', 'A']; chB = ['Bm', 'G', 'D', 'A', 'Bm', 'G', 'A', 'D']
    chs = ['D', 'A/C#', 'Bm', 'G'] + chA + chB + chA + chB + ['D', 'D']
    L = len(chs) * bar + 5; mx = Mix(L)
    for i, c in enumerate(chs):
        t0 = i * bar
        if i < len(chs) - 1:
            arp(mx, harp, V[c], [0, 1, 2, 3, 2, 1], t0, b / 2, t0 + bar, pan=-.25, gain=.26)
        if 4 <= i < 36:
            pad(mx, PD[c], t0, bar, gain=.045 if i < 20 else .075)
        if 20 <= i < 36:
            mx.add(strings(hz(BS[c]), bar, .5, bright=1200, att=.3), t0, .3, .12, .4, 'bass')
    mel(mx, flute, mA + mB, 4 * bar, b, pan=.15, gain=.42, vel=.6, leg=.97, tag='flute')
    mel(mx, celesta, mA, 20 * bar, b, pan=.2, gain=.4, vel=.6, leg=1.4, tag='cel')
    mel(mx, flute, mB, 28 * bar, b, pan=.15, gain=.42, vel=.65, leg=.97, tag='flute')
    mel(mx, strings, mB, 28 * bar, b, pan=-.2, gain=.07, vel=.5, shift=-1, tag='strmel')
    roll(mx, harp, ['D3', 'A3', 'D4', 'F#4', 'A4', 'D5'], 37 * bar, 4)
    mx.add(celesta(hz('A5'), 2, .4), 37 * bar + .4, .3, .3, .5, 'cel')
    ambience_birds(mx, L); ambience_wind(mx, L, .015)
    mx.render('m0', rt=2.6)


def kenangan_lampau():
    """Old memories. A minor, 4/4, piano with strings."""
    b = 60 / 66; bar = 4 * b
    V = {'Am': ['A2', 'E3', 'A3', 'C4'], 'F': ['F2', 'C3', 'F3', 'A3'], 'C': ['C3', 'G3', 'C4', 'E4'],
         'G': ['G2', 'D3', 'G3', 'B3'], 'Dm': ['D3', 'A3', 'D4', 'F4'], 'E': ['E2', 'B2', 'E3', 'G#3'],
         'Em': ['E2', 'B2', 'E3', 'G3']}
    PD = {'Am': ['A3', 'C4', 'E4'], 'F': ['A3', 'C4', 'F4'], 'C': ['G3', 'C4', 'E4'], 'G': ['G3', 'B3', 'D4'],
          'Dm': ['A3', 'D4', 'F4'], 'E': ['G#3', 'B3', 'E4'], 'Em': ['G3', 'B3', 'E4']}
    prog = ['Am', 'F', 'C', 'G', 'Am', 'F', 'Dm', 'E', 'F', 'G', 'Em', 'Am', 'F', 'G', 'E', 'Am']
    m = P("A4:1 C5:1 E5:2 | F5:1.5 E5:.5 C5:2 | D5:1 E5:1 G5:1 E5:1 | D5:3 B4:1 | C5:1 E5:1 A5:2 |"
          " G5:1.5 F5:.5 C5:2 | F5:1 E5:1 D5:1 A4:1 | B4:2 G#4:1 B4:1 | C5:2 A5:2 | B5:1.5 A5:.5 G5:2 |"
          " G5:1 E5:1 B4:1 E5:1 | A5:3 r:1 | F5:1 A5:1 C6:2 | B5:1 D6:1 B5:1 G5:1 | G#5:2 E5:2 | A5:4")
    chs = ['Am', 'F'] + prog + prog + ['Am', 'Am']
    L = len(chs) * bar + 6; mx = Mix(L)
    for i, c in enumerate(chs):
        t0 = i * bar
        if i < len(chs) - 1:
            arp(mx, piano, V[c], [0, 1, 2, 1, 3, 1, 2, 1], t0, b / 2, t0 + bar, pan=-.2, gain=.22, vel=.38, tag='lh')
        if 18 <= i < 34:
            pad(mx, PD[c], t0, bar, gain=.06)
            mx.add(strings(hz(V[c][0]) * (2 if V[c][0][-1] == '2' else 1), bar, .5, bright=1100, att=.5),
                   t0, .3, .12, .4, 'bass')
    mel(mx, piano, m, 2 * bar, b, pan=.1, gain=.5, vel=.62, leg=1.05, tag='rh')
    mel(mx, piano, m, 18 * bar, b, pan=.1, gain=.5, vel=.66, leg=1.05, tag='rh')
    mel(mx, celesta, m[len(m) // 2:], 26 * bar, b, pan=.35, gain=.16, vel=.5, leg=1.2, shift=1, tag='cel')
    mel(mx, piano, P("E5:2 C5:2 | A4:4"), 34 * bar, b, pan=.1, gain=.45, vel=.5, leg=1.3, tag='rh')
    roll(mx, piano, ['A2', 'E3', 'A3', 'C4', 'E4'], 35 * bar, 5, gap=.08, gain=.3, vel=.4)
    mx.render('m3', rt=3.2)


def perjalanan():
    """On the road. G major, 6/8, flute, harp and a frame drum."""
    e = .3; bar = 6 * e
    V = {'G': ['G2', 'D3', 'G3', 'B3'], 'C': ['C3', 'G3', 'C4', 'E4'], 'D': ['D3', 'A3', 'D4', 'F#4'],
         'Em': ['E2', 'B2', 'E3', 'G3']}
    PD = {'G': ['B3', 'D4', 'G4'], 'C': ['C4', 'E4', 'G4'], 'D': ['A3', 'D4', 'F#4'], 'Em': ['B3', 'E4', 'G4']}
    prog = ['G', 'C', 'G', 'D', 'G', 'C', 'D', 'G', 'Em', 'C', 'G', 'D', 'Em', 'C', 'D', 'G']
    m = P("D5:2 B4:1 D5:2 G5:1 | E5:2 G5:1 E5:2 C5:1 | D5:2 B4:1 G4:2 B4:1 | A4:2 B4:1 A4:2 F#4:1 |"
          " D5:2 B4:1 D5:2 G5:1 | A5:2 G5:1 E5:2 G5:1 | F#5:2 E5:1 D5:2 F#5:1 | G5:5 r:1 |"
          " B5:2 G5:1 E5:2 G5:1 | A5:2 G5:1 E5:2 C5:1 | D5:2 G5:1 B5:2 G5:1 | A5:3 F#5:3 |"
          " G5:2 E5:1 B4:2 E5:1 | C5:2 E5:1 G5:2 E5:1 | D5:2 F#5:1 A5:2 F#5:1 | G5:5 r:1")
    chs = ['G', 'C', 'G', 'D'] + prog + prog + ['G', 'G']
    L = len(chs) * bar + 5; mx = Mix(L)
    for i, c in enumerate(chs):
        t0 = i * bar
        if i < len(chs) - 2:
            arp(mx, harp, V[c], [0, 2, 3, 1, 2, 3], t0, e, t0 + bar, pan=-.3, gain=.25, vel=.55)
        if 2 <= i < len(chs) - 2:
            mx.add(drum(.7), t0 + hum(.004), .05, .3, .15, 'drum')
            mx.add(drum(.42), t0 + 3 * e + hum(.004), .05, .3, .15, 'drum')
            mx.add(drum(.22, 120), t0 + 5 * e + hum(.004), .05, .3, .15, 'drum')
        if 4 <= i < 36:
            pad(mx, PD[c], t0, bar, gain=.04 if i < 20 else .065)
    mel(mx, flute, m, 4 * bar, e, pan=.15, gain=.42, vel=.62, leg=.95, tag='flute')
    mel(mx, flute, m, 20 * bar, e, pan=.15, gain=.42, vel=.66, leg=.95, tag='flute')
    mel(mx, celesta, m[len(m) // 2:], 28 * bar, e, pan=-.35, gain=.14, vel=.5, leg=1.3, shift=1, tag='cel')
    roll(mx, harp, ['G2', 'D3', 'G3', 'B3', 'D4', 'G4'], 36 * bar, 3.5)
    mx.add(drum(.6), 36 * bar, .05, .3, .2, 'drum')
    ambience_birds(mx, L, .025); ambience_wind(mx, L, .02)
    mx.render('m1', rt=2.2)


def malam_bintang():
    """Starlit night. E dorian, 4/4, celesta, harp and crickets."""
    b = 60 / 58; bar = 4 * b
    V = {'Em': ['E2', 'B2', 'G3', 'B3'], 'A': ['A2', 'E3', 'A3', 'C#4'], 'D': ['D3', 'A3', 'D4', 'F#4'],
         'C': ['C3', 'G3', 'C4', 'E4']}
    PD = {'Em': ['G3', 'B3', 'E4'], 'A': ['A3', 'C#4', 'E4'], 'D': ['A3', 'D4', 'F#4'], 'C': ['G3', 'C4', 'E4']}
    prog = ['Em', 'A', 'Em', 'D', 'C', 'D', 'Em', 'Em']
    m = P("E5:1 G5:1 B5:2 | C#6:2 A5:1 E5:1 | G5:1 F#5:1 E5:2 | F#5:2 D5:2 | E5:1 G5:1 C6:2 |"
          " B5:1 A5:1 F#5:2 | G5:2 F#5:1 D5:1 | E5:4")
    chs = ['Em', 'A'] + prog * 3 + ['Em', 'Em']
    L = len(chs) * bar + 6; mx = Mix(L)
    for i, c in enumerate(chs):
        t0 = i * bar
        if i < len(chs) - 1:
            arp(mx, harp, V[c], [0, 1, 2, 3], t0, b, t0 + bar, pan=-.3, gain=.26, vel=.45)
        if i < len(chs) - 1:
            pad(mx, PD[c], t0, bar, gain=.04 if i < 18 else .06, att=1.2, rel=1.5, bright=1800)
            mx.add(strings(hz(V[c][0]) * 2, bar, .45, bright=900, att=1.0, rel=1.2), t0, .25, .1, .4, 'bass')
    mel(mx, celesta, m, 2 * bar, b, pan=.25, gain=.42, vel=.55, leg=1.4, tag='cel')
    mel(mx, celesta, m, 10 * bar, b, pan=.25, gain=.36, vel=.5, leg=1.4, tag='cel')
    mel(mx, flute, m, 10 * bar, b, pan=-.1, gain=.3, vel=.5, leg=.97, shift=-1, tag='flute')
    mel(mx, piano, m, 18 * bar, b, pan=.1, gain=.42, vel=.5, leg=1.3, tag='piano')
    mel(mx, celesta, P("E6:1 B5:1 G5:1 E5:3"), 26 * bar, b, pan=.25, gain=.36, vel=.45, leg=1.6, tag='cel')
    mx.add(cricket(L, 4600), 0, -.6, .012, .3, 'amb'); mx.add(cricket(L, 4900), 0, .6, .01, .3, 'amb')
    ambience_wind(mx, L, .012)
    mx.render('m4', rt=3.6)


def pertarungan():
    """Battle. D minor, 120 BPM, strings ostinato, horn and timpani."""
    b = .5; bar = 4 * b
    R = {'Dm': 'D3', 'Bb': 'Bb2', 'C': 'C3', 'A': 'A2', 'Gm': 'G2'}
    PD = {'Dm': ['D4', 'F4', 'A4'], 'Bb': ['D4', 'F4', 'Bb4'], 'C': ['E4', 'G4', 'C5'], 'A': ['E4', 'A4', 'C#5'],
          'Gm': ['D4', 'G4', 'Bb4']}
    prog = ['Dm', 'Bb', 'C', 'A', 'Dm', 'Bb', 'Gm', 'A']
    m = P("D5:2 F5:1 A5:1 | Bb5:2 A5:1 F5:1 | G5:1.5 A5:.5 G5:1 E5:1 | A5:3 E5:1 |"
          " F5:1 E5:1 D5:1 F5:1 | F5:1 D5:1 Bb4:2 | G5:1 Bb5:1 D6:1 Bb5:1 | A5:2 C#5:1 E5:1")
    chs = ['Dm', 'Bb', 'C', 'A'] + prog * 3 + ['Dm', 'Dm']
    L = len(chs) * bar + 4; mx = Mix(L)
    for i, c in enumerate(chs):
        t0 = i * bar; r = midi(R[c])
        if i < 28:
            for k, off in enumerate([0, 0, 7, 0, 12, 0, 7, 0]):
                v = .7 if k % 2 == 0 else .5
                mx.add(strings(hzm(r + off), .14, v, bright=4200, att=.012, rel=.07, voices=2), t0 + k * b / 2 + hum(.003),
                       -.35, .26, .2, 'ost')
                if i >= 12:
                    mx.add(strings(hzm(r - 12), .14, v, bright=2000, att=.012, rel=.07, voices=2), t0 + k * b / 2,
                           .3, .2, .2, 'ost')
            tf = hzm(r - 12 if r - 12 >= 43 else r)
            mx.add(timp(tf, .8), t0, 0, .4, .25, 'timp'); mx.add(timp(tf, .55), t0 + 2 * b, 0, .4, .25, 'timp')
            if i % 8 == 3:
                for k in range(8): mx.add(timp(tf, .3 + .06 * k, 1.0), t0 + 2 * b + k * b / 4, 0, .45, .25, 'timp')
            if i >= 4: pad(mx, PD[c], t0, bar, gain=.05 if i < 20 else .08, att=.2, rel=.4, bright=3500)
    mel(mx, horn, m, 4 * bar, b, pan=.15, gain=.4, vel=.7, leg=.95, tag='horn')
    mel(mx, horn, m, 12 * bar, b, pan=.15, gain=.4, vel=.8, leg=.95, tag='horn')
    mel(mx, strings, m, 12 * bar, b, pan=-.2, gain=.12, vel=.6, leg=1.0, att=.05, rel=.3, bright=5000, tag='strmel')
    # third pass: strings an octave up, horn an octave down
    t = 20 * bar
    for nn, bb in m:
        if nn:
            mx.add(strings(hz(nn) * 2, bb * b, .65, bright=5500, att=.05, rel=.3), t + hum(), -.15, .16, .35, 'strmel')
            mx.add(horn(hz(nn) / 2, bb * b * .95, .8), t + hum(), .2, .38, .3, 'horn')
        t += bb * b
    mx.add(cymbal(2.5, .35), 12 * bar, .2, .3, .4, 'cym'); mx.add(cymbal(2.5, .4), 20 * bar, -.2, .3, .4, 'cym')
    mx.add(cymbal(2.0, .3, swell=True), 28 * bar - 2.0, 0, .3, .4, 'cym')
    t0 = 28 * bar
    for k in range(16): mx.add(timp(hz('D2'), .25 + .04 * k, .8), t0 + k * b / 4, 0, .45, .25, 'timp')
    t1 = 29 * bar
    mx.add(timp(hz('D2'), 1.0, 3), t1, 0, .55, .3, 'timp'); mx.add(cymbal(3, .45), t1, 0, .3, .4, 'cym')
    pad(mx, ['D3', 'A3', 'D4', 'F4', 'A4'], t1, 1.6, gain=.1, att=.02, rel=1.2, bright=4000)
    mx.add(horn(hz('D4'), 1.5, .85), t1, .2, .35, .35, 'horn'); mx.add(horn(hz('D5'), 1.5, .85), t1, -.1, .3, .35, 'horn')
    mx.render('battle', rt=2.0, lufs=-16, fade=2.5)


def benteng():
    """The fortress. G mixolydian, a slow march: horn, strings, harp, timpani and a side drum."""
    b = 60 / 92; bar = 4 * b
    V = {'G': ['G2', 'D3', 'G3', 'B3'], 'F': ['F2', 'C3', 'F3', 'A3'], 'C': ['C3', 'G3', 'C4', 'E4'],
         'Em': ['E2', 'B2', 'E3', 'G3'], 'D': ['D3', 'A3', 'D4', 'F#4']}
    PD = {'G': ['G3', 'B3', 'D4'], 'F': ['F3', 'A3', 'C4'], 'C': ['G3', 'C4', 'E4'], 'Em': ['G3', 'B3', 'E4'],
          'D': ['F#3', 'A3', 'D4']}
    pA = ['G', 'F', 'C', 'G', 'Em', 'C', 'D', 'D']; pB = ['C', 'G', 'F', 'C', 'Em', 'C', 'D', 'G']
    mA = P("G4:2 B4:1 D5:1 | C5:2 A4:1 F4:1 | E5:1.5 D5:.5 C5:1 G4:1 | D5:3 r:1 | E5:2 G5:1 E5:1 |"
           " C5:1.5 D5:.5 E5:1 G5:1 | F#5:2 E5:1 D5:1 | D5:2 A4:2")
    mB = P("E5:2 G5:2 | D5:1 B4:1 G4:2 | A4:1 C5:1 F5:2 | E5:3 r:1 | G5:1.5 F#5:.5 E5:1 B4:1 |"
           " C5:1 E5:1 G5:2 | A5:2 F#5:1 D5:1 | G5:4")
    chs = ['G', 'F', 'C', 'G'] + pA + pB + pA + pB + ['G', 'G']
    L = len(chs) * bar + 5; mx = Mix(L)
    for i, c in enumerate(chs):
        t0 = i * bar
        if i < len(chs) - 1:
            arp(mx, harp, V[c], [0, 2, 3, 1], t0, b, t0 + bar, pan=-.3, gain=.2, vel=.5)
            pad(mx, PD[c], t0, bar, gain=.05 if i < 20 else .075, att=.5, rel=.7)
            mx.add(strings(hz(V[c][0]) * (2 if V[c][0][-1] == '2' else 1), bar, .55, bright=1100, att=.2), t0, .3,
                   .14, .35, 'bass')
            mx.add(timp(hz(V[c][0][:-1] + '2'), .55), t0 + hum(.003), 0, .32, .25, 'timp')
            if i >= 2:
                for k in (1, 3):
                    mx.add(snare(.32 if k == 1 else .4), t0 + k * b + hum(.004), .15, .3, .2, 'snare')
                if i % 8 == 7:
                    for k in range(4): mx.add(snare(.2 + .05 * k), t0 + 3 * b + k * b / 4, .15, .3, .2, 'snare')
    mel(mx, horn, mA + mB, 4 * bar, b, pan=.15, gain=.36, vel=.62, leg=.95, tag='horn')
    mel(mx, horn, mA + mB, 20 * bar, b, pan=.15, gain=.36, vel=.7, leg=.95, tag='horn')
    t = 20 * bar
    for nn, bb in mA + mB:
        if nn: mx.add(strings(hz(nn) * 2, bb * b, .5, bright=4500, att=.08, rel=.4), t + hum(), -.2, .1, .4, 'strmel')
        t += bb * b
    mx.add(cymbal(2.5, .3), 20 * bar, 0, .3, .4, 'cym')
    roll(mx, harp, ['G2', 'D3', 'G3', 'B3', 'D4', 'G4'], 37 * bar, 3.5)
    mx.add(timp(hz('G2'), .8, 3), 37 * bar, 0, .4, .3, 'timp')
    mx.add(horn(hz('G4'), 2.2, .6), 37 * bar, .15, .3, .4, 'horn'); mx.add(horn(hz('D4'), 2.2, .55), 37 * bar, -.1, .25, .4, 'horn')
    mx.render('m2', rt=2.6)


def takhta():
    """The throne. D major, slow and wide: strings, horn, a soft choir, harp and timpani."""
    b = 60 / 64; bar = 4 * b
    V = {'D': ['D3', 'A3', 'D4', 'F#4'], 'Bm': ['B2', 'F#3', 'B3', 'D4'], 'G': ['G2', 'D3', 'G3', 'B3'],
         'A': ['A2', 'E3', 'A3', 'C#4'], 'F#m': ['F#2', 'C#3', 'F#3', 'A3']}
    PD = {'D': ['F#3', 'A3', 'D4'], 'Bm': ['F#3', 'B3', 'D4'], 'G': ['G3', 'B3', 'D4'], 'A': ['E3', 'A3', 'C#4'],
          'F#m': ['F#3', 'A3', 'C#4']}
    prog = ['D', 'Bm', 'G', 'A', 'D', 'F#m', 'G', 'A', 'Bm', 'G', 'D', 'A', 'G', 'A', 'A', 'D']
    m = P("F#4:2 A4:2 | B4:3 A4:1 | G4:2 B4:1 D5:1 | C#5:3 A4:1 | D5:2 F#5:2 | E5:2 C#5:2 |"
          " D5:1 B4:1 G4:1 B4:1 | A4:4 | F#5:2 D5:1 B4:1 | G5:2 D5:2 | A5:3 F#5:1 | E5:4 |"
          " D5:1 E5:1 G5:1 B5:1 | A5:2 G5:1 E5:1 | E5:2 C#5:1 E5:1 | D5:4")
    chs = ['D', 'A'] + prog + prog + ['D', 'D']
    L = len(chs) * bar + 6; mx = Mix(L)
    for i, c in enumerate(chs):
        t0 = i * bar
        if i < len(chs) - 1:
            arp(mx, harp, V[c], [0, 1, 2, 3, 2, 1, 2, 3], t0, b / 2, t0 + bar, pan=-.35, gain=.18, vel=.45)
            pad(mx, PD[c], t0, bar, gain=.055 if i < 18 else .08, att=.8, rel=1.2, bright=2200)
            for j, nn in enumerate(PD[c]):
                mx.add(choir(hz(nn) * 2, bar, .45, 'a' if i >= 18 else 'o'), t0, -.4 + .4 * j, .05 if i < 18 else .07, .6, 'choir')
            mx.add(strings(hz(V[c][0]) * (2 if V[c][0][-1] == '2' else 1), bar, .5, bright=1000, att=.6, rel=1.0),
                   t0, .3, .15, .4, 'bass')
            if i >= 18 and i < 34:
                mx.add(timp(hz(V[c][0][:-1] + '2'), .5), t0, 0, .32, .3, 'timp')
    for k in range(12): mx.add(timp(hz('D2'), .15 + .03 * k, .8), bar + 2 * b + k * b / 6, 0, .3, .3, 'timp')
    mel(mx, strings, m, 2 * bar, b, pan=-.1, gain=.2, vel=.55, leg=1.0, att=.25, rel=.6, bright=3800, tag='strmel')
    mel(mx, horn, m, 18 * bar, b, pan=.15, gain=.36, vel=.66, leg=.97, tag='horn')
    mel(mx, strings, m, 18 * bar, b, pan=-.15, gain=.14, vel=.55, leg=1.0, att=.2, rel=.6, bright=4500, shift=1, tag='strmel')
    mx.add(cymbal(3, .3), 18 * bar, 0, .3, .5, 'cym')
    t1 = 34 * bar
    pad(mx, ['D3', 'A3', 'D4', 'F#4', 'A4', 'D5'], t1, 2 * bar - 1, gain=.08, att=1.0, rel=2.0)
    for nn in ['D4', 'F#4', 'A4']: mx.add(choir(hz(nn), 2 * bar - 1, .5), t1, 0, .07, .6, 'choir')
    mx.add(horn(hz('D4'), 4, .6), t1, .15, .32, .45, 'horn'); mx.add(horn(hz('A3'), 4, .55), t1, -.1, .28, .45, 'horn')
    mx.add(timp(hz('D2'), .8, 3), t1, 0, .4, .3, 'timp')
    roll(mx, harp, ['D3', 'A3', 'D4', 'F#4', 'A4', 'D5', 'F#5'], t1, 4, gap=.08)
    mx.render('m5', rt=3.4)


def sfx():
    """the effects that belong with this music: wrong, rise, levelup, fanfare"""
    def one(name, build, L, rt=2.4):
        mx = Mix(L); build(mx); mx.render(name, rt=rt, lufs=-18, fade=min(1.0, L / 3))

    def wrong(mx):
        mx.add(harp(hz('F4'), .25, .45), 0, 0, .45, .4, 'arp'); mx.add(harp(hz('D4'), .4, .4), .16, 0, .45, .4, 'arp')

    def levelup(mx):
        gl = ['D4', 'E4', 'F#4', 'A4', 'B4', 'D5', 'E5', 'F#5', 'A5', 'B5', 'D6']
        for j, nn in enumerate(gl): mx.add(harp(hz(nn), 1.2, .5), j * .055, -.5 + j / 10, .35, .5, 'arp')
        for nn in ['D6', 'F#6', 'A6']: mx.add(celesta(hz(nn), 1.0, .5), .65, .3, .3, .6, 'cel')
        pad(mx, ['D4', 'F#4', 'A4'], .4, 1.4, gain=.08, att=.4, rel=1.0)

    def rise(mx):
        sc = ['D6', 'E6', 'F#6', 'A6', 'B6', 'D7']
        for k in range(14):
            mx.add(celesta(hz(sc[rng.integers(0, 6)]), .2, .35), k * .08 + rng.uniform(0, .03), rng.uniform(-.8, .8), .3, .7, 'cel')
        mx.add(cymbal(1.4, .2, swell=True), 0, 0, .3, .6, 'cym')

    def fanfare(mx):
        b = .32
        for nn, t, d in [('D4', 0, 1), ('A4', 1, .5), ('D5', 1.5, .5), ('F#5', 2, 1), ('A5', 3, 3)]:
            mx.add(horn(hz(nn), d * b * .95, .8), t * b, .1, .4, .35, 'horn')
        mx.add(timp(hz('D2'), .8), 0, 0, .5, .3, 'timp'); mx.add(timp(hz('A1'), .7), 2 * b, 0, .5, .3, 'timp')
        mx.add(timp(hz('D2'), 1.0), 3 * b, 0, .55, .3, 'timp')
        pad(mx, ['D4', 'F#4', 'A4', 'D5'], 3 * b, 1.6, gain=.09, att=.05, rel=1.2, bright=4000)
        mx.add(cymbal(2.5, .35), 3 * b, 0, .3, .4, 'cym')

    one('wrong', wrong, 1.4); one('levelup', levelup, 3.2); one('rise', rise, 2.6, 3.0); one('fanfare', fanfare, 4.0)


if __name__ == '__main__':
    jobs = {'m0': hutan_pagi, 'm1': perjalanan, 'm2': benteng, 'm3': kenangan_lampau, 'm4': malam_bintang, 'm5': takhta,
            'battle': pertarungan, 'sfx': sfx}
    for k in (sys.argv[1:] or jobs):
        jobs[k]()
