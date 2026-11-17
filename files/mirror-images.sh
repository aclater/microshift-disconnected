#!/bin/bash
# Runs on the connected prep VM. Copies every MicroShift release image, and the extra images given as
# arguments, into /var/bundle/images/NNN, and records each name in /var/bundle/images/list.txt.
set -euo pipefail

authfile=/root/pull-secret.json
dest=/var/bundle/images
release=/usr/share/microshift/release/release-$(uname -m).json

mkdir -p "${dest}"
: > "${dest}/list.tmp"

n=0
for image in $(jq -r '.images[]' "${release}") "$@"; do
    n=$((n + 1))
    dir=$(printf '%03d' "${n}")
    rm -rf "${dest:?}/${dir}"
    echo "${dir} ${image}"
    skopeo copy --quiet --retry-times 5 --preserve-digests --authfile "${authfile}" \
        "docker://${image}" "dir:${dest}/${dir}"
    echo "${dir} ${image}" >> "${dest}/list.tmp"
done

# The list appears only when every image is there, so an interrupted run is repeated in full.
mv "${dest}/list.tmp" "${dest}/list.txt"
