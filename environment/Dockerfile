# hash:sha256:8473e81d0a0df148c737c880877ad37a81b0f94b9cbd998f721142421b02226c
ARG REGISTRY_HOST
FROM $REGISTRY_HOST/codeocean/ubuntu-desktop-igv-fiji-mambaforge:24.11.3-2-python3.12.9-fiji20250521-1118-firefox139.0-igv2.19.4-guacamole1.5.5-ubuntu24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG GIT_ASKPASS
COPY git-ask-pass /

ENV FSLDIR=/opt/fsl
ENV FSLOUTPUTTYPE=NIFTI_GZ
ENV ANTSPATH=/opt/ants/bin
ENV FREESURFER_HOME=/usr/local/freesurfer/8.2.0
ENV SUBJECTS_DIR=/usr/local/freesurfer/8.2.0/subjects
ENV FUNCTIONALS_DIR=/usr/local/freesurfer/8.2.0/sessions
ENV FSFAST_HOME=/usr/local/freesurfer/8.2.0/fsfast
ENV MNI_DIR=/usr/local/freesurfer/8.2.0/mni
ENV MINC_BIN_DIR=/usr/local/freesurfer/8.2.0/mni/bin
ENV MINC_LIB_DIR=/usr/local/freesurfer/8.2.0/mni/lib
ENV FS_LICENSE=/data/freesurfer_license/license.txt
ENV PATH=/opt/fsl/share/fsl/bin:/opt/afni:/opt/ants/bin:/usr/local/freesurfer/8.2.0/bin:/usr/local/freesurfer/8.2.0/fsfast/bin:/usr/local/freesurfer/8.2.0/tktools:/usr/local/freesurfer/8.2.0/mni/bin:$PATH

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bc \
        curl \
        file \
        gsl-bin \
        libcurl4-openssl-dev \
        libglu1-mesa-dev \
        libglw1-mesa-dev \
        libgomp1 \
        libjpeg62 \
        libssl-dev \
        libxm4 \
        libxml2-dev \
        netpbm \
        python3-matplotlib \
        python3-numpy \
        python3-pil \
        tcsh \
        unzip \
        wget \
        xfonts-base \
        xterm \
        xvfb \
    && rm -rf /var/lib/apt/lists/*

# 1. FSL 6.0.7.23 (full install: FSLeyes + fslpy) via the official installer.
#    Flags are taken from the installer's own --help, which is kept at
#    /opt/fslinstaller_help.txt for the record.
RUN set -eu; \
    mkdir -p /tmp/fslinst; \
    curl -fsSL -o /tmp/fslinst/fslinstaller.py \
        https://fsl.fmrib.ox.ac.uk/fsldownloads/fslconda/releases/fslinstaller.py; \
    python3 /tmp/fslinst/fslinstaller.py --help > /opt/fslinstaller_help.txt 2>&1 || true; \
    cat /opt/fslinstaller_help.txt; \
    FSLARGS="-d /opt/fsl -V 6.0.7.23"; \
    if grep -q -- "--skip_registration" /opt/fslinstaller_help.txt; then FSLARGS="$FSLARGS --skip_registration"; fi; \
    if grep -q -- "--no_env" /opt/fslinstaller_help.txt; then FSLARGS="$FSLARGS --no_env"; fi; \
    if grep -q -- "--no_shell" /opt/fslinstaller_help.txt; then FSLARGS="$FSLARGS --no_shell"; fi; \
    echo "fslinstaller args: $FSLARGS"; \
    python3 /tmp/fslinst/fslinstaller.py $FSLARGS; \
    rm -rf /tmp/fslinst /root/.cache /opt/fsl/pkgs; \
    cat /opt/fsl/etc/fslversion; \
    test -x /opt/fsl/share/fsl/bin/bet

# 2. AFNI, Ubuntu 24 binaries (R setup deliberately skipped).
RUN set -eu; \
    mkdir -p /opt/afni /tmp/afnidl; \
    curl -fsSL -o /tmp/afnidl/linux_ubuntu_24_64.tgz \
        https://afni.nimh.nih.gov/pub/dist/tgz/linux_ubuntu_24_64.tgz; \
    tar -xzf /tmp/afnidl/linux_ubuntu_24_64.tgz -C /opt/afni --strip-components=1; \
    rm -rf /tmp/afnidl; \
    /opt/afni/afni -ver

# 3. ANTs 2.6.5
RUN set -eu; \
    mkdir -p /tmp/antsdl; \
    curl -fsSL -o /tmp/antsdl/ants.zip \
        https://github.com/ANTsX/ANTs/releases/download/v2.6.5/ants-2.6.5-ubuntu-24.04-X64-gcc.zip; \
    unzip -q /tmp/antsdl/ants.zip -d /tmp/antsdl/x; \
    SRC="$(dirname "$(find /tmp/antsdl/x -type d -name bin | head -n 1)")"; \
    mkdir -p /opt/ants; \
    cp -a "$SRC"/. /opt/ants/; \
    rm -rf /tmp/antsdl; \
    /opt/ants/bin/antsRegistration --version

# 4. FreeSurfer 8.2.0 (~9.6 GB .deb downloaded, installed and deleted in this step).
RUN set -eu; \
    curl -fsSL -o /tmp/freesurfer.deb \
        https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/8.2.0/freesurfer_ubuntu24-8.2.0_amd64.deb; \
    apt-get update; \
    apt-get install -y --no-install-recommends /tmp/freesurfer.deb; \
    rm -f /tmp/freesurfer.deb; \
    rm -rf /var/lib/apt/lists/*; \
    ls -d /usr/local/freesurfer/*; \
    test -x /usr/local/freesurfer/8.2.0/bin/mri_convert

# 5. dcm2niix v1.0.20261029
RUN set -eu; \
    mkdir -p /tmp/dcm; \
    curl -fsSL -o /tmp/dcm/dcm2niix_lnx.zip \
        https://github.com/rordenlab/dcm2niix/releases/download/v1.0.20261029/dcm2niix_lnx.zip; \
    unzip -o -q /tmp/dcm/dcm2niix_lnx.zip -d /tmp/dcm/x; \
    install -m 0755 "$(find /tmp/dcm/x -type f -name dcm2niix | head -n 1)" /usr/local/bin/dcm2niix; \
    rm -rf /tmp/dcm; \
    test -x /usr/local/bin/dcm2niix

# 6. Same tool settings for shells the virtual desktop opens. Docker ENV reaches only processes the
#    container starts; the desktop session starts its own shells without it, so a desktop terminal
#    could not find fsleyes, afni or freeview. Values are copied from the ENV above at build time.
RUN set -eu; \
    f=/etc/profile.d/neuroimaging.sh; \
    echo '# Neuroimaging tool settings (copied from the image ENV) for desktop-session shells.' > "$f"; \
    for v in FSLDIR FSLOUTPUTTYPE ANTSPATH FREESURFER_HOME SUBJECTS_DIR FUNCTIONALS_DIR FSFAST_HOME MNI_DIR MINC_BIN_DIR MINC_LIB_DIR FS_LICENSE; do \
        printf 'export %s="%s"\n' "$v" "$(printenv "$v")" >> "$f"; \
    done; \
    echo 'for d in /usr/local/freesurfer/8.2.0/mni/bin /usr/local/freesurfer/8.2.0/tktools /usr/local/freesurfer/8.2.0/fsfast/bin /usr/local/freesurfer/8.2.0/bin /opt/ants/bin /opt/afni /opt/fsl/share/fsl/bin; do case ":$PATH:" in *":$d:"*) ;; *) PATH="$d:$PATH" ;; esac; done; export PATH' >> "$f"; \
    echo '[ -r /etc/profile.d/neuroimaging.sh ] && . /etc/profile.d/neuroimaging.sh' >> /etc/bash.bashrc; \
    cat "$f"; \
    env -i HOME=/root PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin bash -c '. /etc/profile.d/neuroimaging.sh && command -v fsleyes afni freeview antsRegistration dcm2niix'
