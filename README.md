# Neuroimaging environment for Code Ocean

A Code Ocean capsule whose environment bundles the core neuroimaging tools: FSL (with FSLeyes and fslpy), AFNI with tcsh, ANTs, FreeSurfer and dcm2niix. It is built on Code Ocean's Ubuntu 24.04 virtual-desktop image, so the GUI viewers (FSLeyes, the AFNI GUI and Freeview) can be used from a cloud workstation desktop. `code/run` checks every tool, command-line and GUI alike.

## What's installed

| Tool | Version | Location |
|---|---|---|
| FSL | 6.0.7.23 (fslpy 3.27.0, FSLeyes 1.20.1) | `/opt/fsl`, commands in `/opt/fsl/share/fsl/bin` |
| AFNI | AFNI_26.3.07, `linux_ubuntu_24_64` build | `/opt/afni` |
| tcsh | 6.24.10 | system package |
| ANTs | 2.6.5 | `/opt/ants/bin` |
| FreeSurfer | 8.2.0 | `/usr/local/freesurfer/8.2.0` |
| dcm2niix | v1.0.20261029 | `/usr/local/bin/dcm2niix` |

Base image: `codeocean/ubuntu-desktop-igv-fiji-mambaforge:24.11.3-2-python3.12.9-fiji20250521-1118-firefox139.0-igv2.19.4-guacamole1.5.5-ubuntu24.04`, which provides a GNOME desktop through Guacamole and also includes IGV, Fiji and Firefox.

Ubuntu 24.04 is needed because AFNI no longer publishes an Ubuntu 22.04 build. Each tool is installed in its own `RUN` step in [`environment/Dockerfile`](environment/Dockerfile), from the pinned upstream download.

## Use it on Code Ocean

1. **New Capsule → Copy from Git**, then paste `https://github.com/codeocean-nate/neuroimaging-env`. **Clone from Git** also works if you want the capsule to stay linked to the repository. Your deployment must offer the base image above as a starter environment.
2. Click **Reproducible Run**. The first run builds the image, which is large (the FreeSurfer package alone is 9.6 GB) and took about 28 minutes end to end in testing. Later runs reuse the built image.
3. To use the GUIs, launch a cloud workstation with **Ubuntu Desktop**, open **Terminal** and run, for example:
   ```bash
   fsleyes $FSLDIR/data/standard/MNI152_T1_1mm.nii.gz &
   afni $FSLDIR/data/standard/MNI152_T1_2mm.nii.gz
   freeview -v $FSLDIR/data/standard/MNI152_T1_2mm.nii.gz &
   ```

## Licenses you need

- **FreeSurfer** needs a `license.txt` for `recon-all` and most processing. It is free: register at <https://surfer.nmr.mgh.harvard.edu/registration.html>. The environment expects it at `/data/freesurfer_license/license.txt`, so put the file in a data asset and attach it with mount name `freesurfer_license`. To keep it elsewhere, point `FS_LICENSE` at that path.
- **FSL** is free for non-commercial use; commercial use needs a license. See <https://fsl.fmrib.ox.ac.uk/fsl/docs/license.html>.
- AFNI, ANTs and dcm2niix have their own open-source licenses. This repository only contains the build recipe and checks; it does not redistribute any of the tools.

## What `code/run` checks

A Reproducible Run executes `code/run`, which runs two scripts and fails if any check fails.

- [`code/check_tools.sh`](code/check_tools.sh) runs 13 command-line checks. They include FSL `bet` on the MNI152 template, fslpy and FSLeyes imports, `afni -ver` and `3dinfo`, `antsRegistration` and `N4BiasFieldCorrection`, `mri_convert`, `mri_info` and `recon-all --version`, `dcm2niix -v` and `tcsh --version`. It writes `/results/checks.txt` and `/results/versions.txt`.
- [`code/check_gui.sh`](code/check_gui.sh) runs 5 GUI checks on a virtual X display (Xvfb):
  - a shell started with an empty environment, as a desktop terminal is, still finds the tools
  - FSLeyes renders the template offscreen
  - AFNI saves its axial view
  - Freeview saves a screenshot
  - all three GUIs stay open together for 60 seconds, and the screen is captured

  It writes `/results/gui_checks.txt` and the images to `/results/gui/`. Checks count an image only if it exists and isn't blank. The full-screen capture installs `x11-apps` and `imagemagick` at run time, so that check needs internet access.

All 18 checks passed on Code Ocean on 2026-11-05.

## Notes

- Docker `ENV` settings don't reach shells that the desktop session starts. The last Dockerfile step therefore writes the same settings to `/etc/profile.d/neuroimaging.sh` and loads it from `/etc/bash.bashrc`, so desktop terminals find the tools.
- `fsleyes --version` sometimes exits with code 120 after printing its version, from a shutdown race in the wrapper. `dcm2niix -v` exits 3 when given no input. The checks for both look for the version string instead of the exit code.
- The apps start from a terminal. There are no desktop menu entries for them.
- AFNI's optional R packages are not installed.
- The Dockerfile is written for Code Ocean: it builds on `$REGISTRY_HOST/codeocean/...` and copies Code Ocean's `git-ask-pass` helper. To build it elsewhere, you would need to change the `FROM` line and drop the `COPY git-ask-pass /` line; that hasn't been tested.
