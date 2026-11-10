#!/usr/bin/env python3
"""Makes every sound of Verbarium from scratch (no samples, so nothing to license):

  ambient.ogg   a 96 s court ambience in D Dorian that loops without a seam: drone, harp, a quiet flute, a soft drum
  quill, seal, wrong, page, tap, rise, fanfare   short effects

Needs numpy, scipy and ffmpeg (libvorbis). Run from the repository root:
    python3 content/tools/make_audio.py
Writes mobile/android/app/src/main/res/raw/*.ogg (played by MainActivity.kt).
"""
import os
import subprocess
import tempfile

import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "mobile", "android", "app", "src", "main", "res", "raw")
rng = np.random.default_rng(1215)  # fixed seed: the same sound on every run


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def lowpass(x, f, order=2):
    return signal.sosfiltfilt(signal.butter(order, f, "low", fs=SR, output="sos"), x)


def highpass(x, f, order=2):
    return signal.sosfiltfilt(signal.butter(order, f, "high", fs=SR, output="sos"), x)


def bandpass(x, lo, hi, order=2):
    return signal.sosfiltfilt(signal.butter(order, [lo, hi], "band", fs=SR, output="sos"), x)


def pluck(freq, dur, bright=1.0, damp=1.0):
    """A plucked string (harp or lute): harmonics that die faster the higher they are."""
    t = np.arange(int(dur * SR)) / SR
    y = np.zeros_like(t)
    k = 1
    while k * freq < 9000 and k <= 24:
        amp = np.sin(np.pi * k * 0.23) / k ** (1.15 / bright)  # plucked a quarter of the way along
        decay = damp * (1.1 + 0.42 * k + 0.012 * k * k)
        y += amp * np.exp(-decay * t) * np.sin(2 * np.pi * k * freq * (1 + 0.00012 * k * k) * t)
        k += 1
    attack = np.minimum(1.0, t / 0.004)
    return y * attack


def flute(freq, dur):
    n = int((dur + 0.35) * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.004 * np.sin(2 * np.pi * 4.8 * t) * np.clip((t - 0.25) / 0.5, 0, 1)
    ph = 2 * np.pi * np.cumsum(freq * vib) / SR
    y = np.sin(ph) + 0.22 * np.sin(2 * ph) + 0.07 * np.sin(3 * ph)
    breath = bandpass(rng.standard_normal(n), freq * 1.5, min(freq * 6, 12000)) * 0.05
    env = np.clip(t / 0.09, 0, 1) * np.clip((dur + 0.35 - t) / 0.35, 0, 1)
    return (y + breath) * env


def drum(dur=0.6):
    t = np.arange(int(dur * SR)) / SR
    f = 62 + 40 * np.exp(-t / 0.03)
    y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.16)
    skin = lowpass(rng.standard_normal(t.size), 900) * np.exp(-t / 0.02) * 0.5
    return y + skin


def room(n, seconds, seed):
    """A hall: decaying noise, darker as it fades."""
    r = np.random.default_rng(seed)
    m = int(seconds * SR)
    t = np.arange(m) / SR
    ir = r.standard_normal(m) * np.exp(-t / (seconds / 5.5))
    ir = lowpass(ir, 4200)
    ir[: int(0.012 * SR)] *= np.linspace(0, 1, int(0.012 * SR))
    ir /= np.sqrt(np.sum(ir ** 2))
    out = np.zeros(n)
    out[: min(m, n)] = ir[:n]
    return out


def reverb(x, seconds, seed, circular):
    n = x.size
    if circular:  # the tail wraps round, so a loop has no seam
        return np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(room(n, seconds, seed)), n)
    pad = int(seconds * SR)
    xx = np.concatenate([x, np.zeros(pad)])
    return np.fft.irfft(np.fft.rfft(xx) * np.fft.rfft(room(xx.size, seconds, seed)), xx.size)


def circular(fn, x, *args):
    """Filters a loop as a loop: wrap a second of sound round each end, filter, cut it off again."""
    pad = SR
    return fn(np.concatenate([x[-pad:], x, x[:pad]]), *args)[pad:-pad]


def put(buf, at, y, gain=1.0, wrap=True):
    i = int(at * SR)
    if wrap:
        idx = (i + np.arange(y.size)) % buf.size
        np.add.at(buf, idx, y * gain)
    else:
        j = min(buf.size, i + y.size)
        buf[i:j] += y[: j - i] * gain


def save(name, left, right=None, peak=0.8):
    right = left if right is None else right
    st = np.stack([left, right], axis=1)
    st = st / np.max(np.abs(st)) * peak
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        wav = f.name
    wavfile.write(wav, SR, (st * 32767).astype(np.int16))
    os.makedirs(OUT, exist_ok=True)
    out = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "3", out], check=True)
    os.unlink(wav)
    print(f"{name}.ogg  {left.size / SR:.2f} s  {os.path.getsize(out) // 1024} kB")


# ------------------------------------------------------------------ ambience

def ambient():
    beat = 1.0  # 60 beats a minute, three beats to the bar
    bar = 3 * beat
    bars = 32
    n = int(bars * bar * SR)
    t = np.arange(n) / SR
    harp_l, harp_r = np.zeros(n), np.zeros(n)
    fl = np.zeros(n)
    dr = np.zeros(n)

    # the ground under each bar (root, as MIDI): D D C D | F C D D, four times
    ground = [38, 38, 36, 38, 41, 36, 38, 38] * 4
    drone = np.zeros(n)
    for b, root in enumerate(ground):
        seg = int(bar * SR) + int(0.8 * SR)
        tt = np.arange(seg) / SR
        env = np.clip(tt / 0.8, 0, 1) * np.clip((bar + 0.8 - tt) / 0.8, 0, 1)
        y = np.zeros(seg)
        for m, g in ((root, 1.0), (root + 7, 0.55), (root + 12, 0.4)):
            f0 = hz(m)
            for det in (0.9985, 1.0, 1.0016):
                for k, a in ((1, 1.0), (2, 0.42), (3, 0.2), (4, 0.09), (5, 0.05)):
                    y += g * a * np.sin(2 * np.pi * f0 * det * k * tt + rng.uniform(0, 6.28))
        put(drone, b * bar - 0.4, y * env)
    drone = circular(lowpass, drone, 900) * (0.82 + 0.18 * np.sin(2 * np.pi * t / 12.0))

    # the tune, as (bar, beat, MIDI note, beats held); bars count from 0
    D4, E4, F4, G4, A4, B4, C5, D5, C4 = 62, 64, 65, 67, 69, 71, 72, 74, 60
    tune = [
        (0, 0, A4, 2), (0, 2, D5, 1), (1, 0, C5, 1), (1, 1, B4, 1), (1, 2, A4, 1), (2, 0, G4, 2), (2, 2, A4, 1),
        (3, 0, F4, 1), (3, 1, E4, 1), (3, 2, D4, 1),
        (4, 0, F4, 2), (4, 2, A4, 1), (5, 0, G4, 1), (5, 1, F4, 1), (5, 2, E4, 1), (6, 0, C4, 2), (6, 2, E4, 1),
        (7, 0, D4, 3),
        (8, 0, D5, 2), (8, 2, C5, 1), (9, 0, A4, 2), (9, 2, G4, 1), (10, 0, A4, 1), (10, 1, B4, 1), (10, 2, C5, 1),
        (11, 0, A4, 3),
        (12, 0, G4, 2), (12, 2, F4, 1), (13, 0, E4, 2), (13, 2, D4, 1), (14, 0, C4, 1), (14, 1, D4, 1), (14, 2, E4, 1),
        (15, 0, D4, 3),
    ]
    # first time through: the harp carries the tune. second time: a flute, the harp answering an octave below
    for b, bt, note, held in tune:
        at = b * bar + bt * beat
        y = pluck(hz(note), 3.2, bright=1.0)
        put(harp_l, at, y, 0.62)
        put(harp_r, at + 0.004, y, 0.5)
        at2 = (b + 16) * bar + bt * beat
        put(fl, at2, flute(hz(note), held * beat * 0.96), 0.5)
        if bt == 0:
            y2 = pluck(hz(note - 12), 3.0, bright=0.8)
            put(harp_l, at2 + 1.5 * beat, y2, 0.28)
            put(harp_r, at2 + 1.5 * beat, y2, 0.34)

    # broken chords under everything: root, fifth, octave
    for b, root in enumerate(ground):
        for i, step in enumerate((12, 19, 24)):
            y = pluck(hz(root + step), 2.6, bright=0.7, damp=1.2)
            g = 0.3 if i == 0 else 0.2
            put(harp_l, b * bar + i * beat, y, g * 0.9)
            put(harp_r, b * bar + i * beat + 0.006, y, g)
        if b % 2 == 0:
            put(dr, b * bar, drum(), 0.5)
        if b % 8 == 7:
            put(dr, b * bar + 2 * beat, drum(), 0.3)

    dry_l = drone * 0.06 + harp_l + fl * 0.8 + dr * 0.5
    dry_r = drone * 0.06 + harp_r + fl + dr * 0.5
    wet_l = reverb(dry_l, 2.6, 7, True)
    wet_r = reverb(dry_r, 2.6, 8, True)
    left = circular(highpass, dry_l * 0.7 + wet_l * 0.55, 55)
    right = circular(highpass, dry_r * 0.7 + wet_r * 0.55, 55)
    print("seam step", round(float(abs(left[0] - left[-1]) / np.max(np.abs(left))), 4),
          "ordinary step p99", round(float(np.percentile(np.abs(np.diff(left)), 99) / np.max(np.abs(left))), 4))
    save("ambient", left, right, peak=0.6)


# ------------------------------------------------------------------ effects

def quill():
    n = int(0.36 * SR)
    t = np.arange(n) / SR
    y = bandpass(rng.standard_normal(n), 2200, 7000)
    env = np.zeros(n)
    for start, length, amp in ((0.0, 0.11, 1.0), (0.12, 0.07, 0.7), (0.2, 0.13, 0.9)):
        tt = (t - start) / length
        m = (tt > 0) & (tt < 1)
        env[m] += amp * np.sin(np.pi * tt[m]) ** 0.7
    env *= 0.75 + 0.25 * np.sin(2 * np.pi * 43 * t)
    save("quill", y * env, peak=0.5)


def seal():
    n = int(0.42 * SR)
    t = np.arange(n) / SR
    f = 58 + 70 * np.exp(-t / 0.025)
    thump = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.09)
    click = lowpass(rng.standard_normal(n), 2500) * np.exp(-t / 0.008) * 0.6
    wax = lowpass(rng.standard_normal(n), 700) * np.exp(-t / 0.07) * 0.25
    y = thump + click + wax
    w = reverb(y, 0.5, 3, False)
    save("seal", np.concatenate([y, np.zeros(w.size - n)]) * 0.9 + w * 0.25, peak=0.85)


def wrong():
    n = int(0.5 * SR)
    y = np.zeros(n)
    put(y, 0.0, pluck(hz(53), 0.3, bright=0.6, damp=7), 1.0, wrap=False)
    put(y, 0.13, pluck(hz(50), 0.35, bright=0.6, damp=6), 0.9, wrap=False)
    save("wrong", lowpass(y, 1800), peak=0.6)


def page():
    n = int(0.32 * SR)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    sweep = np.zeros(n)
    for i in range(6):  # a band that climbs, as a leaf of paper turns
        lo = 900 + i * 700
        part = bandpass(noise, lo, lo + 1500)
        tt = (t - i * 0.035) / 0.16
        m = (tt > 0) & (tt < 1)
        e = np.zeros(n)
        e[m] = np.sin(np.pi * tt[m]) ** 2
        sweep += part * e
    save("page", sweep, peak=0.4)


def tap():
    y = pluck(1150, 0.07, bright=0.5, damp=60)
    save("tap", y, peak=0.35)


def rise():
    n = int(1.3 * SR)
    y = np.zeros(n)
    for i, note in enumerate((62, 65, 69, 74)):
        put(y, i * 0.085, pluck(hz(note), 1.1, bright=1.1), 0.8, wrap=False)
    w = reverb(y, 1.2, 5, False)
    save("rise", np.concatenate([y, np.zeros(w.size - n)]) + w * 0.4, peak=0.7)


def brass(freq, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.003 * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.3) / 0.4, 0, 1)
    ph = 2 * np.pi * np.cumsum(freq * vib) / SR
    bloom = np.clip(t / 0.06, 0, 1)  # the tone opens up as it speaks
    y = np.zeros(n)
    k = 1
    while k * freq < 7000 and k <= 14:
        y += np.sin(k * ph) / k ** (1.9 - 0.7 * bloom)
        k += 1
    env = np.clip(t / 0.03, 0, 1) * np.clip((dur - t) / 0.09, 0, 1) * (0.85 + 0.15 * np.exp(-t / 0.2))
    return y * env


def fanfare():
    n = int(2.9 * SR)
    y = np.zeros(n)
    # D D A | D' held, with the fifth and the octave under it
    for at, note, dur, g in ((0.0, 62, 0.17, 0.8), (0.2, 62, 0.17, 0.8), (0.4, 69, 0.34, 0.9), (0.78, 74, 1.7, 1.0)):
        put(y, at, brass(hz(note), dur), g, wrap=False)
    put(y, 0.78, brass(hz(69), 1.7), 0.55, wrap=False)
    put(y, 0.78, brass(hz(50), 1.7), 0.5, wrap=False)
    for at, g in ((0.0, 0.8), (0.4, 0.6), (0.78, 1.0)):
        put(y, at, drum(0.7), g * 1.6, wrap=False)
    y = lowpass(y, 5200)
    w = reverb(y, 1.8, 11, False)
    save("fanfare", np.concatenate([y, np.zeros(w.size - n)]) * 0.75 + w * 0.5, peak=0.8)


if __name__ == "__main__":
    ambient()
    quill()
    seal()
    wrong()
    page()
    tap()
    rise()
    fanfare()
