#!/bin/bash

#
# Copyright (C) 2023 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

# Terminate on error
set -e

# Prepare variables for later use
images=()
# The image will be pushed to GitHub container registry
repobase="${REPOBASE:-ghcr.io/nethserver}"
# Configure the image name
reponame="discourse"
discourse_image="docker.io/discourse/discourse:2026.7.4"
# discourse/postgres only publishes major tags: the digest pins the exact image
postgres_image="docker.io/discourse/postgres:pg18@sha256:17aafaf96ee15c89e5ca0e42aa7fc2f3baeb83f0fb5b9e3bbc5f87c2c4c7e6e5"
redis_image="docker.io/redis:8.10.2-alpine"

# Show the upstream version in the About page, the metadata file is restored on exit
metadata_file="ui/public/metadata.json"
metadata_backup=$(mktemp)
cleanup() {
    cp "${metadata_backup}" "${metadata_file}"
    rm -f "${metadata_backup}"
}
cp "${metadata_file}" "${metadata_backup}"
trap cleanup EXIT
jq --arg v "${discourse_image##*:}" \
    '.upstream_name |= gsub("version set automatically"; $v)' \
    "${metadata_file}" > "${metadata_file}.tmp" && mv "${metadata_file}.tmp" "${metadata_file}"

# Create a new empty container image
container=$(buildah from scratch)

# Reuse existing nodebuilder-discourse container, to speed up builds
if ! buildah containers --format "{{.ContainerName}}" | grep -q nodebuilder-discourse; then
    echo "Pulling NodeJS runtime..."
    buildah from --name nodebuilder-discourse -v "${PWD}:/usr/src:Z" docker.io/library/node:lts
fi

echo "Build static UI files with node..."
buildah run \
    --workingdir=/usr/src/ui \
    --env="NODE_OPTIONS=--openssl-legacy-provider" \
    nodebuilder-discourse \
    sh -c "corepack enable && yarn install && yarn build"

# Add imageroot directory to the container image
buildah add "${container}" imageroot /imageroot
buildah add "${container}" ui/dist /ui
buildah config --entrypoint=/ \
    --label="org.nethserver.authorizations=traefik@node:routeadm" \
    --label="org.nethserver.tcp-ports-demand=1" \
    --label="org.nethserver.rootfull=0" \
    --label="org.nethserver.min-core=3.20.1" \
    --label="org.nethserver.images=${postgres_image} ${redis_image} ${discourse_image}" \
    --label="org.nethserver.volumes=discourse-shared" \
    "${container}"
# Commit the image
buildah commit "${container}" "${repobase}/${reponame}"

# Append the image URL to the images array
images+=("${repobase}/${reponame}")

#
# NOTICE:
#
# It is possible to build and publish multiple images.
#
# 1. create another buildah container
# 2. add things to it and commit it
# 3. append the image url to the images array
#

#
# Setup CI when pushing to Github. 
# Warning! docker::// protocol expects lowercase letters (,,)
if [[ -n "${CI}" ]]; then
    # Set output value for Github Actions
    printf "images=%s\n" "${images[*],,}" >> "${GITHUB_OUTPUT}"
else
    # Just print info for manual push
    printf "Publish the images with:\n\n"
    for image in "${images[@],,}"; do printf "  buildah push %s docker://%s:%s\n" "${image}" "${image}" "${IMAGETAG:-latest}" ; done
    printf "\n"
fi
