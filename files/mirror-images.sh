#!/bin/bash
# Runs on the connected prep VM. Copies every MicroShift release image, and the extra images given as
# arguments, into /var/bundle/images/NNN, and records each name in /var/bundle/images/list.txt.
set -euo pipefail

authfile=/root/pull-secret.json
dest=/var/bundle/images
release=/usr/share/microshift/release/release-$(uname -m).json

mkdir -p "${dest}"
: > "${dest}/list.txt"

n=0
for image in $(jq -r '.images[]' "${release}") "$@"; do
    n=$((n + 1))
    dir=$(printf '%03d' "${n}")
    echo "${dir} ${image}"
    skopeo copy --quiet --retry-times 3 --preserve-digests --authfile "${authfile}" \
        "docker://${image}" "dir:${dest}/${dir}"
    echo "${dir} ${image}" >> "${dest}/list.txt"
done
