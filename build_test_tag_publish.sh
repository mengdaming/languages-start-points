#!/bin/bash
set -e

readonly TMP_DIR=$(mktemp -d /tmp/cyber-dojo.languages-start-points.XXXXXXXXX)
trap "rm -rf ${TMP_DIR} > /dev/null" INT EXIT
readonly ROOT_DIR="$( cd "$( dirname "${0}" )" && pwd )"
readonly SHA=$(cd "${ROOT_DIR}" && git rev-parse HEAD)
readonly TAG="${SHA:0:7}"

# - - - - - - - - - - - - - - - - - - - - - - - -
build_the_images()
{
  if on_ci; then
    cd ${TMP_DIR}
    curl_script
    chmod 700 ./$(script_name)
  fi
  build_image all
  build_image common
  build_image small
}

# - - - - - - - - - - - - - - - - - - - - - - - -
build_image()
{
  local -r kind="${1}"
  $(script_path) start-point create \
    $(image_name ${kind}) \
      --languages \
        $(language_urls "${kind}")
}

# - - - - - - - - - - - - - - - - - - - - - - - -
image_name()
{
  local -r kind="${1}"
  echo "cyberdojo/languages-start-points-${kind}"
}

# - - - - - - - - - - - - - - - - - - - - - - - -
curl_script()
{
  local -r repo=commander
  local -r branch=master
  local -r url="$(github_org)/${repo}/${branch}/$(script_name)"
  curl -O --silent --fail "${url}"
}

# - - - - - - - - - - - - - - - - - - - - - - - -
github_org()
{
    echo https://raw.githubusercontent.com/cyber-dojo
}

# - - - - - - - - - - - - - - - - - - - - - - - -
script_name()
{
  echo cyber-dojo
}

# - - - - - - - - - - - - - - - - - - - - - - - -
script_path()
{
  if on_ci; then
    echo "./$(script_name)"
  else
    echo "${ROOT_DIR}/../commander/$(script_name)"
  fi
}

# - - - - - - - - - - - - - - - - - - - - - - - -
language_urls()
{
  local -r kind="${1}"
  if on_ci; then
    local -r repo=languages-start-points
    local -r branch=master
    local -r url_base="$(github_org)/${repo}/${branch}"
    local -r urls="$(curl --silent --fail "${url_base}/start-points/${kind}")"
  else
    local -r urls="$(cat "${ROOT_DIR}/start-points/${kind}")"
  fi
  echo "${urls}"
}

# - - - - - - - - - - - - - - - - - - - - - - - -
tag_the_images()
{
  tag_image all
  tag_image common
  tag_image small
  echo "${SHA}"
  echo "${TAG}"
}

# - - - - - - - - - - - - - - - - - - - - - - - -
tag_image()
{
  local -r kind="${1}"
  local -r image="$(image_name ${kind})"
  docker tag ${image}:latest ${image}:${TAG}
}

# - - - - - - - - - - - - - - - - - - - - - - - -
on_ci()
{
  [ -n "${CIRCLECI}" ]
}

# - - - - - - - - - - - - - - - - - - - - - - - -
on_ci_publish_tagged_images()
{
  if ! on_ci; then
    echo 'not on CI so not publishing tagged images'
    return
  fi
  echo 'on CI so publishing tagged images'
  # DOCKER_USER, DOCKER_PASS are in ci context
  echo "${DOCKER_PASS}" | docker login --username "${DOCKER_USER}" --password-stdin
  publish_image all
  publish_image common
  publish_image small
  docker logout
}

# - - - - - - - - - - - - - - - - - - - - - - - -
publish_image()
{
  local -r kind="${1}"
  local -r image="$(image_name ${kind})"
  docker push ${image}:latest
  docker push ${image}:${TAG}
}

# - - - - - - - - - - - - - - - - - - - - - - - -
build_the_images
tag_the_images
on_ci_publish_tagged_images