"""Synthesizes Media/AuctionSale.ogg: a register's rattling keys, a small bright bell and coins.

    pip install numpy soundfile
    python3 docs/dev/auction-sale-sound.py Media/AuctionSale.ogg
"""
import sys

import numpy as np
import soundfile as sf

RATE = 44100
LENGTH = 1.25
BELL_AT = 0.33
rng = np.random.default_rng(11)
out = np.zeros(int(RATE * LENGTH))


def add(start, sound, gain):
    at = int(start * RATE)
    sound = sound[: len(out) - at]
    out[at:at + len(sound)] += gain * sound


def ring(partials, seconds):
    """Partials (frequency, gain, decay), struck within a millisecond."""
    t = np.arange(int(seconds * RATE)) / RATE
    tone = sum(g * np.exp(-t / d) * np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) for f, g, d in partials)
    return tone * np.minimum(1, t / 0.001)


def noise(seconds, low, high):
    """Noise between two frequencies, at an RMS of 1."""
    n = int(seconds * RATE)
    spectrum = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1 / RATE)
    spectrum *= 1 / (1 + (low / np.maximum(f, 1)) ** 4) / (1 + (f / high) ** 4)
    sound = np.fft.irfft(spectrum, n)
    return sound / np.sqrt(np.mean(sound ** 2))


def burst(seconds, attack, decay, low, high):
    t = np.arange(int(seconds * RATE)) / RATE
    return noise(seconds, low, high) * np.minimum(1, t / attack) * np.exp(-t / decay)


# "Cha": the keys go down in a fast, growing rattle, with the body knocking under it.
for i in range(7):
    add(i * 0.021 + rng.uniform(0, 0.004), burst(0.06, 0.001, 0.012, 2200, 11000), 0.08 + 0.035 * i)
add(0.085, burst(0.14, 0.015, 0.035, 2500, 12000), 0.24)
add(0.10, ring([(800, 1, 0.03), (1620, 0.8, 0.025), (2750, 0.6, 0.02), (4950, 0.8, 0.03)], 0.2), 0.12)
add(0.125, burst(0.12, 0.001, 0.02, 120, 900), 0.22)

# The drawer rushes out, into the bell.
t = np.arange(int(0.10 * RATE)) / RATE
add(BELL_AT - 0.10, noise(0.10, 3500, 13000) * (t / 0.10) ** 2.5, 0.22)

# "Ching": the strike, then the bell, high and thin, each partial a slightly beating pair.
add(BELL_AT, burst(0.12, 0.001, 0.025, 1500, 12000), 0.5)
add(BELL_AT, burst(0.12, 0.001, 0.02, 100, 700), 0.16)
BELL = [(1330, 0.16, 0.30), (3390, 0.42, 0.26), (6050, 1.0, 0.20), (9150, 0.42, 0.13)]
add(BELL_AT, ring(BELL + [(f + 7, g * 0.35, d) for f, g, d in BELL], 0.95), 0.24)

# Coins jumping in the drawer: shimmer and single clinks.
add(BELL_AT, burst(0.6, 0.002, 0.17, 6000, 14000), 0.13)
for i in range(12):
    f = rng.uniform(4600, 7600)
    clink = ring([(f, 1, 0.03), (f * 1.43, 0.6, 0.02), (f * 1.9, 0.3, 0.012)], 0.15)
    add(BELL_AT + 0.05 + i * 0.037 + rng.uniform(0, 0.02), clink, 0.13 * (1 - i / 16))

out = np.tanh(1.3 * out / np.max(np.abs(out)) * 1.2)
fade = int(0.2 * RATE)
out[-fade:] *= np.linspace(1, 0, fade)
out *= 0.8 / np.max(np.abs(out))
sf.write(sys.argv[1], out, RATE, format="OGG", subtype="VORBIS")
