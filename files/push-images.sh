#!/bin/bash
# Runs on the distribution server, as root. Pushes the bundle's images into the local registry under the
# same paths they have at Red Hat, without the registry host name. Image signatures that came with an
# image are written to /var/www/html/sigstore (see /etc/containers/registries.d).
# Argument: the registry. The login comes from the environment variables REGISTRY_USER and
# REGISTRY_PASSWORD; it is kept in a root-only file for the length of the run and never on a command line.
set -euo pipefail

registry=$1
authdir=$(mktemp -d /root/push-auth.XXXXXX)
authfile=${authdir}/auth.json
trap 'rm -rf "${authdir}"' EXIT
printf '%s' "${REGISTRY_PASSWORD}" |
    skopeo login --authfile "${authfile}" --username "${REGISTRY_USER}" --password-stdin "${registry}"
src=/var/www/html/bundle/images

while read -r dir image; do
    path=${image#*/}
    case "${path}" in
        # An image named by digest also gets a tag, so the registry never treats it as unused.
        *@sha256:*) digest=${path##*@sha256:}; dest="${path%@*}:sha256-${digest:0:16}" ;;
        *)          dest="${path}" ;;
    esac
    echo "${image} -> ${registry}/${dest}"
    skopeo copy --quiet --all --preserve-digests --dest-authfile "${authfile}" \
        "dir:${src}/${dir}" "docker://${registry}/${dest}"
done < "${src}/list.txt"
