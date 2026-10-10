#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

ITCH_TARGET="${ITCH_TARGET:-avivajpeyi/stop-staring:html5}"
PROJECT_DIR="stop_staring"
[[ $# -le 1 ]] || { echo "Usage: ./publish.sh [--check|--build-only|--dry-run]" >&2; exit 1; }
mode="${1:-publish}"
case "$mode" in
    publish|--check|--build-only|--dry-run) ;;
    --help|-h)
        echo "Usage: ./publish.sh [--check|--build-only|--dry-run]"
        echo "Default: build Web and upload to $ITCH_TARGET"
        echo "Overrides: GODOT_BIN (or GODOT), BUTLER, ITCH_TARGET"
        exit 0 ;;
    *) echo "Unknown option: $mode" >&2; exit 1 ;;
esac

GODOT_BIN="${GODOT_BIN:-${GODOT:-}}"
if [[ -z "$GODOT_BIN" ]]; then
    installed_runtime="$HOME/Library/Application Support/Godot/app_userdata/Godots/versions/Godot_v4_8-dev6_macos_universal/Godot.app/Contents/MacOS/Godot"
    if [[ -x "$installed_runtime" ]]; then
        GODOT_BIN="$installed_runtime"
    else
        GODOT_BIN="$(command -v godot || command -v godot4 || true)"
    fi
fi
[[ -n "$GODOT_BIN" ]] && command -v "$GODOT_BIN" >/dev/null 2>&1 || {
    echo "Set GODOT_BIN to Godot with matching Web export templates." >&2; exit 1;
}
"$GODOT_BIN" --version

publisher="${BUTLER:-butler}"
if [[ -z "${BUTLER:-}" ]] && ! command -v "$publisher" >/dev/null 2>&1; then
    publisher="$HOME/.local/bin/butler"
fi
if [[ "$mode" == publish || "$mode" == --check || "$mode" == --dry-run ]]; then
    command -v "$publisher" >/dev/null 2>&1 || {
        echo "Set BUTLER to your itch.io Butler executable." >&2; exit 1;
    }
    "$publisher" --version
fi
echo "Target: $ITCH_TARGET"
for dependency in python3 rsync; do
    command -v "$dependency" >/dev/null 2>&1 || {
        echo "Missing build dependency: $dependency" >&2; exit 1;
    }
done
python3 - "$PROJECT_DIR" <<'PY_CHECK'
from pathlib import Path
import re
import sys
root = Path(sys.argv[1])
project = root / 'project.godot'
if not project.is_file():
    raise SystemExit(f'Missing Godot project: {project}')
match = re.search(r'^run/main_scene="((?:res|uid)://[^"\n]+)"$', project.read_text(), re.M)
if not match:
    raise SystemExit('No main scene configured. Create a scene in Godot and set it as the project main scene before publishing.')
if match[1].startswith('res://') and not (root / match[1].removeprefix('res://')).is_file():
    raise SystemExit(f'Main scene does not exist: {match[1]}')
PY_CHECK
[[ "$mode" != --check ]] || exit 0

mkdir -p build/web build/staging
touch build/.gdignore
find build/web -maxdepth 1 -type f -delete
rsync -a --delete --delete-excluded \
    --exclude '.git/' --exclude '.godot/' --exclude '.github/' \
    --exclude '.agents/' --exclude '.codex/' --exclude '.env*' \
    --exclude 'addons/godot_ai/' --exclude 'addons/.godot_ai_update/' \
    --exclude 'build/' --exclude '*.sh' "$PROJECT_DIR/" build/staging/
python3 - <<'PY'
from pathlib import Path
import re
project = Path('build/staging/project.godot')
source = project.read_text()
source = re.sub(r'^enabled=PackedStringArray\(.*\)$', 'enabled=PackedStringArray()', source, flags=re.M)
source = re.sub(r'^_mcp_game_helper=.*\n', '', source, flags=re.M)
if '[editor]' not in source:
    source += '\n[editor]\n\nimport/use_multiple_threads=false\n'
else:
    source = re.sub(r'^import/use_multiple_threads=.*\n', '', source, flags=re.M)
    source = source.replace('[editor]', '[editor]\n\nimport/use_multiple_threads=false', 1)
# Web exports require ETC2/ASTC imports, including compatibility projects.
source = re.sub(r'^textures/vram_compression/import_etc2_astc=.*\n', '', source, flags=re.M)
if '[rendering]' not in source:
    source += '\n[rendering]\n'
source = source.replace('[rendering]', '[rendering]\n\ntextures/vram_compression/import_etc2_astc=true', 1)
project.write_text(source)
# Local export presets are ignored, so define the Web preset here.
Path('build/staging/export_presets.cfg').write_text('''[preset.0]
name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
include_filter="CREDITS.md,**/License.txt,**/credits.txt,**/OFL.txt,**/FONTLOG.txt"
exclude_filter="*.sh,README.md"
script_export_mode=2
[preset.0.options]
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=true
html/export_icon=true
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
progressive_web_app/enabled=false
''')
PY
"$GODOT_BIN" --headless --path build/staging --import > build/import.log 2>&1 || {
    cat build/import.log >&2; exit 1;
}
"$GODOT_BIN" --headless --path build/staging --export-release Web ../web/index.html > build/export.log 2>&1 || {
    cat build/export.log >&2; exit 1;
}
python3 - <<'PY'
from pathlib import Path
import re
from zipfile import ZipFile, ZIP_DEFLATED
errors = [f'{log}: {line}' for log in (Path('build/import.log'), Path('build/export.log'))
          for line in log.read_text().splitlines()
          if re.search(r'ERROR:|SCRIPT ERROR:|Parse Error:|handle_crash:', line)]
if errors:
    raise SystemExit('\n'.join(errors))
for name in ('index.html', 'index.js', 'index.wasm', 'index.pck'):
    file = Path('build/web') / name
    if not file.is_file() or file.stat().st_size == 0:
        raise SystemExit(f'Incomplete Web export: {file}')
credits = Path('stop_staring/CREDITS.md')
if not credits.is_file():
    raise SystemExit('Missing asset attribution: stop_staring/CREDITS.md')
Path('build/web/CREDITS.md').write_bytes(credits.read_bytes())
with ZipFile('build/stop-staring-web.zip', 'w', ZIP_DEFLATED) as archive:
    for file in sorted(Path('build/web').iterdir()):
        if file.is_file():
            archive.write(file, file.name)
print('Ready: build/stop-staring-web.zip')
PY
case "$mode" in
    --build-only) exit 0 ;;
    --dry-run) "$publisher" push --dry-run build/web "$ITCH_TARGET" ;;
    publish) "$publisher" push build/web "$ITCH_TARGET" ;;
esac
