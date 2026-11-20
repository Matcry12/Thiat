#!/usr/bin/env python3
"""Generates the hit-feel sound effects as 16-bit mono WAVs (jsfxr-style: noise + sine/square, envelope, low-pass).
Everything is synthesised here from maths, so the files are original and CC0. Placeholders: replace any file in
assets/game/audio/ with a real sound; data/hit_fx/*.tres point at the file names, nothing else changes.
Run: python3 tools/make_sfx.py"""
import math, random, struct, wave, pathlib

RATE = 22050
OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "game" / "audio"


def synth(dur, freq=(440, 440), kind="sine", noise=0.0, attack=0.003, decay=6.0, lp=0.5, partials=(1.0,), seed=1):
    """freq = (start, end) Hz sweep. decay = exponential decay rate. lp = low-pass 0..1 (lower = duller)."""
    rng = random.Random(seed)
    n = int(dur * RATE)
    phase, y, out = 0.0, 0.0, []
    for i in range(n):
        t = i / RATE
        f = freq[0] + (freq[1] - freq[0]) * (i / n)
        phase += 2 * math.pi * f / RATE
        s = 0.0
        for k, amp in enumerate(partials, 1):
            p = math.sin(phase * k)
            s += amp * (p if kind == "sine" else (1.0 if p >= 0 else -1.0) * 0.6)
        s = s / sum(partials) * (1.0 - noise) + rng.uniform(-1, 1) * noise
        env = min(1.0, t / attack) * math.exp(-decay * t / dur)
        y += lp * (s * env - y)
        out.append(y)
    return out


def mix(*layers):
    n = max(len(l) for l in layers)
    return [sum(l[i] for l in layers if i < len(l)) for i in range(n)]


def save(name, samples, peak=0.6):
    m = max(abs(s) for s in samples) or 1.0
    k = peak / m
    fade = int(0.004 * RATE)   # no click at the end
    data = bytearray()
    for i, s in enumerate(samples):
        if i > len(samples) - fade:
            s *= (len(samples) - i) / fade
        data += struct.pack("<h", int(max(-1, min(1, s * k)) * 32767))
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE); w.writeframes(bytes(data))


OUT.mkdir(parents=True, exist_ok=True)
save("hit_sword.wav", mix(synth(0.10, (240, 90), noise=0.0, decay=7), synth(0.07, (0, 0), noise=1.0, decay=8, lp=0.35, seed=2)))
save("hit_boss.wav", mix(synth(0.16, (160, 48), decay=6), synth(0.09, (0, 0), noise=1.0, decay=8, lp=0.25, seed=3)))
save("hit_arrow.wav", mix(synth(0.05, (900, 520), kind="square", decay=8, lp=0.3), synth(0.03, (0, 0), noise=1.0, decay=8, lp=0.5, seed=4)), 0.45)
save("hit_charged.wav", mix(synth(0.18, (320, 70), decay=6), synth(0.07, (0, 0), noise=1.0, decay=7, lp=0.6, seed=5), synth(0.12, (700, 300), kind="square", decay=9, lp=0.25)))
save("parry_chime.wav", synth(0.45, (1320, 1320), decay=5, lp=0.6, partials=(1.0, 0.5, 0.25)), 0.5)
save("block_clunk.wav", mix(synth(0.12, (120, 70), decay=6, lp=0.4), synth(0.06, (0, 0), noise=1.0, decay=8, lp=0.2, seed=6)))
save("player_hurt.wav", synth(0.17, (340, 150), kind="square", decay=5, lp=0.22))
save("boom.wav", mix(synth(0.55, (80, 28), decay=4), synth(0.30, (0, 0), noise=1.0, decay=5, lp=0.15, seed=7)))
# eating (placeholders): chew = 3 short band-passed crunches, sip = bubbly low blip, gulp = low sine with a downward drop
def crunch(dur, seed, lp):
    n = synth(dur, (0, 0), noise=1.0, decay=7, lp=lp, seed=seed)
    return [n[i] - (n[i - 1] if i else 0) * 0.7 for i in range(len(n))]   # high-pass-ish: crisp, not rumbly
save("eat_chew.wav", mix(crunch(0.07, 11, 0.45), [0.0] * int(0.05 * RATE) + crunch(0.06, 12, 0.5), [0.0] * int(0.11 * RATE) + crunch(0.07, 13, 0.4)), 0.5)
save("drink_sip.wav", mix(synth(0.09, (300, 520), decay=6, lp=0.4), synth(0.07, (0, 0), noise=1.0, decay=8, lp=0.2, seed=14)), 0.4)
save("eat_gulp.wav", mix(synth(0.15, (230, 90), decay=5, lp=0.35), synth(0.05, (0, 0), noise=1.0, decay=9, lp=0.2, seed=15)), 0.55)
print("wrote", sorted(p.name for p in OUT.glob("*.wav")))
