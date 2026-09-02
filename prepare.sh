#!/bin/bash
# Fetch the bundled upstream sources at the refs declared in upstream.env
# — the single source of truth shared with debian/scripts/gen-component-sbom.
#
# Sources are extracted into busybox/, swupdate/ and ttyd/. swupdate is
# patched in-tree from patches/ (mail-format, applied as git commits in
# repo mode). busybox is built from the in-tree busybox.config defconfig
# and ttyd is bundled unmodified, so neither is patched here.
#
# Usage:
#   ./prepare.sh            fetch all; swupdate gets a git repo with the
#                           patchset applied as commits (for MR/forking)
#   ./prepare.sh build      fetch all; patches applied with patch -p1
#                           (build mode, used by CI)

set -e

# shellcheck disable=SC1091
. ./upstream.env

create_git_repo() {
    git init
    git add .
    git commit -m "Init from ${2}"
    git am "$1"/*.patch
}

patch_source() {
    for p in "$1"/*.patch; do
        patch -p1 <"$p"
    done
}

# fetch <ref> <repo> <dir>
#   downloads the GitHub archive for <ref> (a tag, commit SHA, or branch)
#   and extracts it into <dir>. The archive extracts to <base>-<ref>.
fetch() {
    local ref="$1" repo="$2" dir="$3"
    local base
    base=${repo##*/}          # last path segment, e.g. "busybox"
    base=${base%.git}
    wget -q "${repo%.git}/archive/${ref}.tar.gz" -O- | tar xz
    mv "${base}-${ref}" "$dir"
}

if ! [ -d busybox ]; then
    fetch "${BUSYBOX_REF:-$BUSYBOX_VERSION}" "$BUSYBOX_REPO" busybox
else
    echo "busybox directory already exists, remove it manually"; exit 0; 
fi

if ! [ -d swupdate ]; then 
fetch "${SWUPDATE_REF:-$SWUPDATE_VERSION}" "$SWUPDATE_REPO" swupdate
(
    cd swupdate
    if [ "$1" = "build" ]; then
        patch_source ../patches
    else
        create_git_repo ../patches "${SWUPDATE_REF:-$SWUPDATE_VERSION}"
    fi
)
else
    echo "swupdate directory already exists, remove it manually"
fi

if ! [ -d ttyd ]; then 
    fetch "${TTYD_REF:-$TTYD_VERSION}" "$TTYD_REPO" ttyd
else
    echo "ttyd directory already exists, remove it manually"
fi
