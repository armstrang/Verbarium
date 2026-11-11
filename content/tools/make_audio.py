#!/usr/bin/env python3
"""Makes every sound of Verbarium from scratch (no samples, so nothing to license):

  quill, seal, page, tap, hit, crit, hurt, victory, defeat   short effects

The music (m0 … m5, battle) and the effects wrong, rise, levelup, fanfare and the lines' taps and hits are made by
make_music.py, from CC0 samples.

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


def bowed(freq, dur, soft=1.0):
    """a fiddle or cello: a slow attack, vibrato that arrives late, a dark top"""
    n = int((dur + 0.25) * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.005 * np.sin(2 * np.pi * 5.4 * t) * np.clip((t - 0.2) / 0.4, 0, 1)
    ph = 2 * np.pi * np.cumsum(freq * vib) / SR
    y = np.zeros(n)
    k = 1
    while k * freq < 4200 and k <= 16:
        y += np.sin(k * ph + 0.3 * k) / k ** (1.25 * soft)
        k += 1
    env = np.clip(t / 0.11, 0, 1) * np.clip((dur + 0.25 - t) / 0.25, 0, 1)
    return y * env * 0.5


def bell(freq, dur=3.0):
    t = np.arange(int(dur * SR)) / SR
    y = np.zeros_like(t)
    for ratio, a, d in ((1, 1.0, 1.2), (2.0, 0.6, 1.8), (2.76, 0.45, 2.6), (5.4, 0.25, 4.0), (8.93, 0.12, 6.0)):
        if freq * ratio < 15000:
            y += a * np.exp(-d * t) * np.sin(2 * np.pi * freq * ratio * t)
    return y * np.minimum(1, t / 0.002) * 0.4


def hit():
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    swish = bandpass(rng.standard_normal(n), 1500, 9000) * np.exp(-((t - 0.05) / 0.035) ** 2)
    f = 70 + 90 * np.exp(-t / 0.02)
    thud = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-(np.maximum(t - 0.09, 0)) / 0.06) * (t > 0.09)
    save("hit", swish * 0.8 + thud, peak=0.7)


def crit():
    n = int(0.9 * SR)
    t = np.arange(n) / SR
    swish = bandpass(rng.standard_normal(n), 2000, 11000) * np.exp(-((t - 0.04) / 0.03) ** 2)
    f = 60 + 120 * np.exp(-t / 0.02)
    thud = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-(np.maximum(t - 0.07, 0)) / 0.08) * (t > 0.07)
    y = swish + thud * 1.2
    put(y, 0.08, bell(hz(93), 0.8), 0.7, wrap=False)
    save("crit", y, peak=0.8)


def hurt():
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    f = 110 - 50 * t / 0.35
    y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.09) + lowpass(rng.standard_normal(n), 1200) * np.exp(-t / 0.03) * 0.7
    save("hurt", y, peak=0.7)


def victory():
    n = int(3.4 * SR)
    y = np.zeros(n)
    for at, note, dur, g in ((0.0, 62, 0.14, 0.7), (0.16, 66, 0.14, 0.7), (0.32, 69, 0.14, 0.8), (0.5, 74, 0.3, 0.9), (0.86, 73, 0.16, 0.8), (1.04, 74, 1.9, 1.0)):
        put(y, at, brass(hz(note), dur), g, wrap=False)
    for note in (57, 66):
        put(y, 1.04, brass(hz(note), 1.9), 0.5, wrap=False)
    put(y, 1.04, bell(hz(86), 2.2), 0.6, wrap=False)
    for at, g in ((0.0, 0.7), (0.5, 0.8), (1.04, 1.0)):
        put(y, at, drum(0.7), g * 1.5, wrap=False)
    y = lowpass(y, 5600)
    w = reverb(y, 1.8, 33, False)
    save("victory", np.concatenate([y, np.zeros(w.size - n)]) * 0.75 + w * 0.5, peak=0.8)


def defeat():
    n = int(2.8 * SR)
    y = np.zeros(n)
    for at, note, dur in ((0.0, 50, 0.7), (0.7, 48, 0.7), (1.4, 45, 1.3)):
        put(y, at, bowed(hz(note), dur, 1.3), 1.0, wrap=False)
        put(y, at, bowed(hz(note - 12), dur, 1.3), 0.8, wrap=False)
    w = reverb(y, 1.6, 35, False)
    save("defeat", np.concatenate([y, np.zeros(w.size - n)]) * 0.8 + w * 0.5, peak=0.6)


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


if __name__ == "__main__":
    for make in (quill, seal, page, tap, hit, crit, hurt, victory, defeat):
        make()
