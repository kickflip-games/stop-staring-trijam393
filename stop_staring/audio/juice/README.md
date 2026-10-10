# Action feedback audio

Two original synthesized mono PCM cues, generated with Python's standard
library by `tools/build_juice_audio.py` in the source repository:

| File | Duration | Use |
|---|---|---|
| `launch.wav` | 130 ms | Sharp launch whoosh |
| `snap.wav` | 85 ms | Eye-impact accent |

Run `python3 tools/build_juice_audio.py` from the repository root to reproduce
the files. The generator uses a fixed noise seed, 44.1 kHz sample rate,
16-bit samples and short edge fades. No external recordings or samples are
used; these cues require no third-party attribution.

The supplied stretch and eye-pop clips, plus the Kenney wall impact, remain
in use. Pause suspends effects, retry stops them, and success cuts them after
the final impact to create a quiet beat.
