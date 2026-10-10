# Web audio repair

Chrome reproduced repeated `NotSupportedError` exceptions in Godot's browser
sample backend: `createBuffer(2, 2457600, 48000) failed`, through
`Sample._duplicateAudioBuffer` and the pause/resume path. The clock also sent
identical music pause and pitch assignments every frame.

The Web override now selects **Stream** (`audio/general/default_playback_type.web=0`).
Music only changes its pause/pitch properties when the requested value changes.
This preserves aiming pitch changes, hit-stop, focus suspension and explicit pause.
The setting applies to both music and the existing default SFX players.
[Godot documents the Stream/Sample setting values here](https://docs.godotengine.org/en/4.3/classes/class_projectsettings.html#class-projectsettings-property-audio-general-default-playback-type).

The supplied BeepBox WAV is 51.2 seconds long but its audible material ends around
13.4 seconds. WAV import now trims silence; the imported loop is approximately
13.18 seconds. The original source WAV is preserved.

Validation in desktop Chrome used a temporary diagnostic Web export, excluded
from the release. Music produced master-bus output, and isolated Aim, Wall, Pop,
Launch and Snap cues all produced output (approximately -43, -31, -34, -19 and
-54 dB respectively). Actual drag launches closed eyes and ricocheted without the
previous browser errors. Music warmup/scene transition regression checks pass;
the broader gameplay regression, independent-eye, home-screen and feedback suites
also passed during this investigation.

The trimmed song wrapped from 12.36 to 0.18 seconds with audible mixer output
continuing. Pause froze playback; resume restored output without errors.
Published with `bash publish.sh`: itch.io html5 build **2103116**, version **7**.
The live itch.io iframe loaded that build, started gameplay, and closed two eyes
after an actual drag launch, with no captured warnings/errors from the new build.
[Live release screenshot](web_audio/release_chrome.jpg).

Physical cellphone playback and long-session memory stability still require
device testing. A desktop Chrome pass does not establish either.
