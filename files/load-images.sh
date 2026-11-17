#!/bin/bash
# Runs on each node, as root. Loads the bundle's images into the container storage CRI-O uses, under the
# names MicroShift asks for, so nothing is ever pulled.
set -euo pipefail

src=/var/bundle/images

while read -r dir image; do
    echo "${image}"
    skopeo copy --quiet --preserve-digests "dir:${src}/${dir}" "containers-storage:${image}"
done < "${src}/list.txt"
