#!/bin/bash
# Runs on the distribution server, as root. Pushes the bundle's images into the local registry under the
# same paths they have at Red Hat, without the registry host name. Image signatures that came with an
# image are written to /var/www/html/sigstore (see /etc/containers/registries.d).
# Argument: the registry. The login comes from the environment variable REGISTRY_CREDS (user:password).
set -euo pipefail

registry=$1
creds=${REGISTRY_CREDS}
src=/var/www/html/bundle/images

while read -r dir image; do
    path=${image#*/}
    case "${path}" in
        # An image named by digest also gets a tag, so the registry never treats it as unused.
        *@sha256:*) digest=${path##*@sha256:}; dest="${path%@*}:sha256-${digest:0:16}" ;;
        *)          dest="${path}" ;;
    esac
    echo "${image} -> ${registry}/${dest}"
    skopeo copy --quiet --all --preserve-digests --dest-creds "${creds}" \
        "dir:${src}/${dir}" "docker://${registry}/${dest}"
done < "${src}/list.txt"
