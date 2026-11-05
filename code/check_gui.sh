#!/usr/bin/env bash
# GUI checks for FSLeyes, the AFNI GUI and Freeview, run headless on a virtual X display (Xvfb).
# Each app opens the FSL MNI152 template and saves an image. An image counts only if it exists
# and is not blank. Writes /results/gui_checks.txt and /results/gui/*.png. Exits non-zero on any failure.
set -uo pipefail

RESULTS=/results
OUT="$RESULTS/gui"
LOG="$RESULTS/gui_checks.txt"
T2="$FSLDIR/data/standard/MNI152_T1_2mm.nii.gz"
T1="$FSLDIR/data/standard/MNI152_T1_1mm.nii.gz"
PY="$FSLDIR/bin/python"
mkdir -p "$OUT"
: > "$LOG"
export LIBGL_ALWAYS_SOFTWARE=1
TOTAL=0
FAILURES=0

# Not blank = at least 5 KB and pixel standard deviation above 5 (a black or flat image fails).
image_ok() {
  "$PY" - "$1" <<'EOF'
import os, sys
import numpy as np
from PIL import Image
p = sys.argv[1]
if not os.path.exists(p):
    sys.exit(f"missing: {p}")
a = np.asarray(Image.open(p).convert("L"), dtype=float)
size = os.path.getsize(p)
print(f"{os.path.basename(p)}: {a.shape[1]}x{a.shape[0]} px, {size} bytes, pixel std {a.std():.1f}")
sys.exit(0 if size > 5000 and a.std() > 5 else "image looks blank")
EOF
}

check() {
  local label="$1" cmd="$2" out status verdict
  out="$(eval "$cmd" 2>&1)"
  status=$?
  TOTAL=$((TOTAL + 1))
  if [ "$status" -eq 0 ]; then verdict=PASS; else verdict=FAIL; FAILURES=$((FAILURES + 1)); fi
  {
    printf '%s  %s  (exit %d)\n' "$verdict" "$label" "$status"
    printf '%s\n' "$out" | tail -n 25 | sed 's/^/      | /'
    printf '\n'
  } >> "$LOG"
}

# Whole-screen capture of the virtual display: use what the image has, else install x11-apps +
# imagemagick for this run only (test harness, not part of the environment).
grab_screen() {
  if command -v import >/dev/null 2>&1; then
    import -display "$DISPLAY" -window root "$1"
  else
    if ! command -v xwd >/dev/null 2>&1 || ! command -v convert >/dev/null 2>&1; then
      apt-get update -qq >/dev/null && apt-get install -y -qq --no-install-recommends x11-apps imagemagick >/dev/null
    fi
    if command -v import >/dev/null 2>&1; then
      import -display "$DISPLAY" -window root "$1"
    else
      xwd -display "$DISPLAY" -root -silent | convert xwd:- "$1"
    fi
  fi
}

# --- virtual display --------------------------------------------------------
Xvfb :99 -screen 0 1920x1080x24 +extension GLX +render -noreset >"$OUT/xvfb.log" 2>&1 &
XVFB_PID=$!
export DISPLAY=:99
sleep 3
{
  printf 'GUI checks on virtual display %s (Xvfb, software OpenGL)\n' "$DISPLAY"
  printf 'run at   %s\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} >> "$LOG"

# --- 1. FSLeyes: offscreen OpenGL render of the 1 mm template ---------------
check 'FSLeyes render (ortho view of MNI152_T1_1mm)' \
  'timeout 180 fsleyes render --outfile "$OUT/fsleyes_render.png" --size 1200 450 --scene ortho "$T1" >/dev/null 2>"$OUT/fsleyes_render.err"; image_ok "$OUT/fsleyes_render.png"'

# --- 2. AFNI GUI: open the template and save the axial image window ---------
check 'AFNI GUI opens template, axial window saved via -com SAVE_PNG (or SAVE_JPEG)' \
  'cd "$OUT" && timeout 120 afni -no_detach -com "OPEN_WINDOW A.axialimage" -com "SAVE_PNG A.axialimage $OUT/afni_axial.png" -com "SAVE_JPEG A.axialimage $OUT/afni_axial.jpg" -com "QUIT" "$T2" >"$OUT/afni.log" 2>&1; image_ok "$OUT/afni_axial.png" || image_ok "$OUT/afni_axial.jpg"'

# --- 3. Freeview: open the template and save a screenshot --------------------
check 'Freeview opens template, axial screenshot via -ss' \
  'timeout 180 freeview -v "$T2" -viewport axial -ss "$OUT/freeview_axial.png" -quit >"$OUT/freeview.log" 2>&1; image_ok "$OUT/freeview_axial.png"'

# --- 4. All three full GUIs open together and stay up ----------------------
check 'FSLeyes, AFNI and Freeview GUIs all running after 60 s; full-screen capture' \
  'fsleyes "$T1" >"$OUT/fsleyes_gui.log" 2>&1 & P1=$!
   ( cd "$OUT" && exec afni -no_detach "$T2" >"$OUT/afni_gui.log" 2>&1 ) & P2=$!
   freeview -v "$T2" >"$OUT/freeview_gui.log" 2>&1 & P3=$!
   sleep 60
   alive=0
   for p in $P1 $P2 $P3; do kill -0 $p 2>/dev/null && alive=$((alive + 1)); done
   echo "processes still running: $alive of 3 (fsleyes $P1, afni $P2, freeview $P3)"
   grab_screen "$OUT/desktop_all_three.png"
   command -v xwininfo >/dev/null 2>&1 && xwininfo -root -tree | grep -iE "fsleyes|afni|freeview" | sed "s/^ *//" | head -n 12
   kill $P1 $P2 $P3 2>/dev/null; pkill -f "[a]fni" 2>/dev/null
   [ "$alive" -eq 3 ] && image_ok "$OUT/desktop_all_three.png"'

kill "$XVFB_PID" 2>/dev/null

{
  printf -- '----\n'
  printf 'GUI checks run: %d, failures: %d\n' "$TOTAL" "$FAILURES"
} >> "$LOG"
printf '\n===== gui_checks.txt =====\n'
cat "$LOG"
[ "$FAILURES" -eq 0 ]
