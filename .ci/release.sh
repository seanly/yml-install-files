#!/bin/bash

set -euo pipefail

if [ ! "$#" -eq 1 ]; then
  echo 'Must provide a version number to release. e.g. 1.0' >&2
  exit 1
fi

[ -d .git ] || {
  echo 'ERROR: must be in repo root to release.' >&@
  exit 1
}

if [ ! "$(git rev-parse HEAD)" = "$(git show-ref -s origin/main)" ]; then
  echo 'ERROR: push to main before releasing.' >&2
  exit 1
fi

if ! git diff --quiet --exit-code; then
  echo 'Cannot release with a dirty workspace.' >&2
  exit
fi

if ! (
    for x in *.sh; do grep "^# download-utilities v$1\$" "${x}"; done
  ) > /dev/null; then
  echo 'Version not updated in scripts.' >&2
  exit 1
fi

tar -c \
  *.sh \
  LICENSE \
  CHANGELOG.md \
  README.md \
  docs \
  checksums/update.sh \
  | gzip -9 > universal.tgz

notes() {
  awk '
    $0 ~ /^# download-utilities/ && notes == 1 { exit; };
    $0 ~ /^# download-utilities/ {notes=1;};
    notes == 1 {print}' < CHANGELOG.md
}

if [ "$#" -lt 1 ]; then
  echo 'Must provide a new git tag release.' >&2
  exit 1
fi

if ! notes | head -n1 | grep "v$1\$" > /dev/null; then
  echo 'ERROR: Release notes not updated for: '"v$1"
  exit 1
fi

[ -d scratch ] || mkdir scratch
./download-utilities.sh download-utilities.yml gh

git tag "v$1"
git push origin refs/tags/"v$1":refs/tags/"v$1"

# Give GitHub the chance to surface the tag in the repo.
echo 'Sleeping for 10 seconds...'
sleep 10

./scratch/gh release create "v$1" --verify-tag \
  --title "download-utilities v$1" \
  --notes "$(notes | grep -vF "# download-utilities v$1" )"

./scratch/gh release upload "v$1" universal.tgz
