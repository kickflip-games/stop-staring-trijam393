#!/usr/bin/env python3
"""Rebuild short original feedback cues with Python's standard library."""
import math
from pathlib import Path
import random
import struct
import wave

RATE = 44100
DESTINATION = Path(__file__).resolve().parents[1] / "stop_staring/audio/juice"


def save(name, duration, signal):
    rng = random.Random(393)
    samples = []
    for index in range(round(duration * RATE)):
        t = index / RATE
        edge = min(1, t / 0.002, (duration - t) / 0.008)
        samples.append(signal(t, t / duration, rng) * max(0, edge))
    peak = max(abs(sample) for sample in samples)
    pcm = b"".join(struct.pack("<h", round(sample / max(1, peak / 0.82) * 32767)) for sample in samples)
    with wave.open(str(DESTINATION / name), "wb") as output:
        output.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        output.writeframes(pcm)


def whoosh(t, u, rng):
    envelope = math.sin(math.pi * u) ** 0.65
    noise = rng.uniform(-1, 1)
    sweep = math.sin(math.tau * (1800 * t - 4900 * t * t))
    return envelope * (noise * 0.55 + sweep * 0.13) * (1 - u * 0.5)


def snap(t, u, rng):
    phase = math.tau * (620 * t - 2300 * t * t)
    return (rng.uniform(-1, 1) * 0.55 + math.sin(phase) * 0.28) * math.exp(-u * 7)


if __name__ == "__main__":
    DESTINATION.mkdir(parents=True, exist_ok=True)
    for name, duration, signal in [("launch.wav", 0.13, whoosh), ("snap.wav", 0.085, snap)]:
        save(name, duration, signal)
        print(f"Wrote {name}: {duration:.3f}s")
