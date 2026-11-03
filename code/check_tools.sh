#!/usr/bin/env bash
# Verify every neuroimaging tool installed in this capsule's environment.
# Writes /results/versions.txt and /results/checks.txt.
# Exits non-zero if any single check fails. No FreeSurfer license required.
set -uo pipefail

RESULTS=/results
CHECKS="$RESULTS/checks.txt"
VERSIONS="$RESULTS/versions.txt"
TEMPLATE="$FSLDIR/data/standard/MNI152_T1_2mm.nii.gz"

mkdir -p "$RESULTS"
: > "$CHECKS"
: > "$VERSIONS"

declare -A OUTPUT
TOTAL=0
FAILURES=0

check() {
  local key="$1" label="$2" cmd="$3"
  local out status verdict
  out="$(eval "$cmd" 2>&1)"
  status=$?
  OUTPUT["$key"]="$out"
  TOTAL=$((TOTAL + 1))
  if [ "$status" -eq 0 ]; then
    verdict=PASS
  else
    verdict=FAIL
    FAILURES=$((FAILURES + 1))
  fi
  {
    printf '%s  %s  (exit %d)\n' "$verdict" "$label" "$status"
    printf '      $ %s\n' "$cmd"
    printf '%s\n' "$out" | sed 's/^/      | /'
    printf '\n'
  } >> "$CHECKS"
}

first_line() {
  printf '%s\n' "${OUTPUT[$1]:-}" | grep -v '^[[:space:]]*$' | head -n 1
}

{
  printf 'Neuroimaging tool verification\n'
  printf 'run at        %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'FSLDIR        %s\n' "${FSLDIR:-unset}"
  printf 'FREESURFER_HOME %s\n' "${FREESURFER_HOME:-unset}"
  printf 'FS_LICENSE    %s (absent by design; not needed by these checks)\n' "${FS_LICENSE:-unset}"
  printf 'template      %s\n\n' "$TEMPLATE"
} >> "$CHECKS"

# --- FSL -------------------------------------------------------------------
check fsl_version 'FSL version ($FSLDIR/etc/fslversion)' 'cat "$FSLDIR/etc/fslversion"'
check fsl_bet 'FSL bet on MNI152_T1_2mm -> /results' 'bet "$TEMPLATE" "$RESULTS/MNI152_T1_2mm_brain" -f 0.5 -g 0 -m && ls -l "$RESULTS"/MNI152_T1_2mm_brain*'
check fsl_python 'fslpy + fsleyes import via $FSLDIR/bin/python' '"$FSLDIR/bin/python" -c "from importlib.metadata import version as v; import fsl, fsleyes; print(\"fslpy\", v(\"fslpy\")); print(\"fsleyes\", v(\"fsleyes\"))"'
check fsleyes_cli 'fsleyes --version (wrapper exit code unreliable at shutdown; PASS requires the version string)' 'o="$(fsleyes --version 2>/dev/null || xvfb-run -a fsleyes --version 2>/dev/null || true)"; printf "%s\n" "$o"; printf "%s" "$o" | grep -q -i "FSLeyes version"'

# --- AFNI ------------------------------------------------------------------
check afni_ver 'afni -ver' 'afni -ver'
check afni_3dinfo '3dinfo -n4 on FSL MNI152 template' '3dinfo -n4 "$TEMPLATE"'

# --- ANTs ------------------------------------------------------------------
check ants_reg 'antsRegistration --version' 'antsRegistration --version'
check ants_n4 'N4BiasFieldCorrection --version' 'N4BiasFieldCorrection --version'

# --- FreeSurfer ------------------------------------------------------------
check fs_mri_convert 'mri_convert --version' 'mri_convert --version'
check fs_mri_info 'mri_info on FSL MNI152 template' 'mri_info "$TEMPLATE"'
check fs_recon_all 'recon-all --version' 'recon-all --version'

# --- dcm2niix --------------------------------------------------------------
check dcm2niix 'dcm2niix -v (exits 3 with no input dir; PASS requires the pinned version string)' 'o="$(dcm2niix -v 2>&1 || true)"; printf "%s\n" "$o"; printf "%s" "$o" | grep -q "v1\.0\.20261029"'

# --- tcsh ------------------------------------------------------------------
check tcsh 'tcsh --version' 'tcsh --version'

# --- versions.txt ----------------------------------------------------------
{
  printf 'FSL                %s\n' "$(first_line fsl_version)"
  printf 'fslpy / fsleyes    %s\n' "$(printf '%s' "${OUTPUT[fsl_python]:-}" | tr '\n' ';' | sed 's/;$//')"
  printf 'FSLeyes CLI        %s\n' "$(printf '%s\n' "${OUTPUT[fsleyes_cli]:-}" | grep -m1 -i 'fsleyes version' || first_line fsleyes_cli)"
  printf 'AFNI               %s\n' "$(first_line afni_ver)"
  printf 'ANTs               %s\n' "$(printf '%s\n' "${OUTPUT[ants_reg]:-}" | grep -i -m1 -E 'ants version|^[0-9]' || first_line ants_reg)"
  printf 'FreeSurfer         %s\n' "$(cat "$FREESURFER_HOME/build-stamp.txt" 2>/dev/null || first_line fs_mri_convert)"
  printf 'dcm2niix           %s\n' "$(printf '%s\n' "${OUTPUT[dcm2niix]:-}" | grep -i -m1 version || first_line dcm2niix)"
  printf 'tcsh               %s\n' "$(first_line tcsh)"
} > "$VERSIONS"

# Keep the installer help that decided the FSL install flags alongside the results.
if [ -f /opt/fslinstaller_help.txt ]; then
  cp /opt/fslinstaller_help.txt "$RESULTS/fslinstaller_help.txt"
fi

{
  printf -- '----\n'
  printf 'checks run: %d, failures: %d\n' "$TOTAL" "$FAILURES"
} >> "$CHECKS"

printf '\n===== versions.txt =====\n'
cat "$VERSIONS"
printf '\n===== checks.txt =====\n'
cat "$CHECKS"

if [ "$FAILURES" -gt 0 ]; then
  printf '\n%d check(s) FAILED\n' "$FAILURES" >&2
  exit 1
fi
printf '\nAll %d checks PASSED\n' "$TOTAL"
