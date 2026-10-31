"""Render the game's original, sample-free score (Python + NumPy + SoundFile).

Both arrangements share a 32-bar, 72 BPM score, so synchronized playback can
crossfade at any point. Reverb tails wrap around the loop instead of being cut.
SoundFile encodes the resulting stereo arrangements to Ogg Vorbis.
"""

from pathlib import Path
import json
import numpy as np
import soundfile as sf

RATE = 44100
BEAT = 60 / 72
FRAMES = round(32 * 4 * BEAT * RATE)
OUT = Path(__file__).resolve().parents[1] / "assets" / "music"
RNG = np.random.default_rng(20261010)

# Two bars per harmony; open, consonant voicings in D major.
HARMONIES = [
    (38, [62, 66, 69, 73, 76]), (35, [62, 66, 69, 71, 74]),
    (31, [59, 62, 66, 69, 74]), (33, [61, 64, 69, 71, 76]),
    (38, [62, 66, 69, 73, 76]), (35, [62, 66, 69, 71, 74]),
    (40, [62, 64, 67, 71, 74]), (33, [61, 64, 69, 71, 76]),
    (31, [59, 62, 66, 69, 74]), (38, [62, 66, 69, 73, 76]),
    (35, [62, 66, 69, 71, 74]), (33, [61, 64, 69, 71, 76]),
    (31, [59, 62, 66, 69, 74]), (40, [62, 64, 67, 71, 74]),
    (33, [61, 64, 69, 71, 76]), (38, [62, 66, 69, 73, 76]),
]
MELODIES = [
    [78, 76, 73, 69], [74, 73, 71, 69],
    [74, 78, 76, 74], [73, 71, 69, None],
    [76, 78, 81, 78], [78, 76, 74, None],
    [76, 74, 71, 69], [73, 76, 71, None],
    [74, 78, 81, 78], [76, 73, 69, None],
    [74, 73, 71, 66], [69, 71, 73, None],
    [78, 76, 74, 69], [76, 74, 71, None],
    [73, 71, 69, 76], [78, 76, 74, None],
]


def voice(note, seconds, kind):
    t = np.arange(round(seconds * RATE)) / RATE
    f = 440 * 2 ** ((note - 69) / 12)
    phase = 2 * np.pi * f * t
    if kind == "pad":
        attack = np.minimum(t / 1.3, 1)
        release = np.minimum((seconds - t) / 2.0, 1)
        env = np.sin(attack * np.pi / 2) ** 2 * np.sin(release * np.pi / 2) ** 2
        tone = (np.sin(phase) + 0.32 * np.sin(phase * 1.0015)
                + 0.13 * np.sin(phase * 2)) / 1.45
    elif kind == "bass":
        env = (1 - np.exp(-t / 0.04)) * np.exp(-t / 1.5)
        tone = np.sin(phase) + 0.12 * np.sin(phase * 2)
    else:
        # Soft electric-piano / rounded plucked-string timbres, no hard attack.
        decay = 1.7 if kind == "piano" else 0.85
        env = (1 - np.exp(-t / 0.012)) * np.exp(-t / decay)
        tone = np.sin(phase + 0.23 * np.sin(phase * 2) * np.exp(-t / 0.4))
        tone += 0.28 * np.sin(phase * 2) * np.exp(-t / 0.5)
        tone += 0.13 * np.sin(phase * 3) * np.exp(-t / 0.23)
        tone += 0.045 * np.sin(phase * 4) * np.exp(-t / 0.12)
    env *= np.minimum((seconds - t) / 0.12, 1)
    return (tone * env).astype(np.float32)


def add_note(mix, note, beat, seconds, amplitude, pan, kind):
    signal = voice(note, seconds, kind) * amplitude
    stereo = signal[:, None] * np.array([np.cos(pan * np.pi / 2), np.sin(pan * np.pi / 2)])
    start = round(beat * BEAT * RATE) % FRAMES
    first = min(len(signal), FRAMES - start)
    mix[start:start + first] += stereo[:first]
    if first < len(signal):
        mix[:len(signal) - first] += stereo[first:]


def render(night):
    mix = np.zeros((FRAMES, 2), dtype=np.float32)
    for section, ((bass, chord), melody) in enumerate(zip(HARMONIES, MELODIES)):
        base = section * 8
        for i, pitch in enumerate(chord[:4]):
            add_note(mix, pitch - 12, base, 8 * BEAT + 2.0,
                     0.020 if night else 0.012, 0.2 + i * 0.2, "pad")
        for offset in ([0, 4] if night else [0, 3.5, 4]):
            add_note(mix, bass, base + offset, 3.8, 0.047 if night else 0.058, 0.5, "bass")
        pattern = [0, 2, 1, 3, 2, 4, 1, 2]
        for tick in range(16):
            if night and tick % 3 != 0:
                continue
            pitch = chord[pattern[tick % 8]]
            timing = base + tick * 0.5 + float(RNG.uniform(0.008, 0.025))
            add_note(mix, pitch, timing, 3.6 if night else 2.8,
                     (0.033 if night else 0.051) * float(RNG.uniform(0.85, 1.10)),
                     0.30 if tick % 2 else 0.68, "piano" if night else "pluck")
        for i, pitch in enumerate(melody):
            if pitch is None or (night and i == 1):
                continue
            add_note(mix, pitch, base + [0.75, 2.25, 4.0, 6.25][i],
                     5.5, 0.065 if night else 0.091, 0.53, "piano")
    # Circular, stereo room reflections preserve tails at the loop boundary.
    wet = np.zeros_like(mix)
    for delay, gain in [(0.113, 0.16), (0.239, 0.13), (0.397, 0.10),
                        (0.631, 0.08), (0.887, 0.06), (1.271, 0.045), (1.739, 0.03)]:
        wet += np.roll(mix[:, ::-1], round(delay * RATE), axis=0) * gain
    mix += wet * (1.0 if night else 0.7)
    mix -= mix.mean(axis=0)
    rms = float(np.sqrt(np.mean(mix ** 2)))
    mix *= min(10 ** (-22 / 20) / rms, 0.56 / float(np.max(np.abs(mix))))
    # A 20 ms edge taper also prevents codec windowing from introducing a click.
    edge = round(0.020 * RATE)
    taper = np.sin(np.linspace(0, np.pi / 2, edge)) ** 2
    mix[:edge] *= taper[:, None]
    mix[-edge:] *= taper[::-1, None]
    return mix


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    report = {}
    for name, night in [("sea_breeze", False), ("moonlit_tide", True)]:
        samples = render(night)
        target = OUT / (name + ".ogg")
        pending = OUT / (name + ".ogg.tmp")
        # Bounded writes avoid oversized buffers in native Vorbis encoders.
        with sf.SoundFile(pending, "w", samplerate=RATE, channels=2, format="OGG", subtype="VORBIS") as audio:
            for start in range(0, FRAMES, 16384):
                audio.write(samples[start:start + 16384])
        decoded, rate = sf.read(pending, dtype="float32")
        assert rate == RATE and decoded.shape == samples.shape
        assert np.max(np.abs(decoded)) < 0.9, "Clipping in encoded soundtrack"
        assert np.max(np.abs(decoded[0] - decoded[-1])) < 0.001, "Audible loop discontinuity"
        # Publish only complete files; an open Godot editor may import at any time.
        pending.replace(target)
        report[name] = {
            "duration_seconds": FRAMES / RATE,
            "peak_dbfs": round(20 * np.log10(float(np.max(np.abs(decoded)))), 2),
            "rms_dbfs": round(20 * np.log10(float(np.sqrt(np.mean(decoded ** 2)))), 2),
            "loop_boundary_step": float(np.max(np.abs(decoded[0] - decoded[-1]))),
            "bytes": target.stat().st_size,
        }
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
