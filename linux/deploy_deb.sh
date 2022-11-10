#!/bin/bash
set -eu -o pipefail

# Create deb files

TARGET_ARCH="${TARGET_ARCH:-amd64}"

cp -r linux/debian .

# get the koord version from pro file
VERSION=$(grep -oP '^VERSION = \K\w[^\s\\]*' Koord.pro)

export DEBFULLNAME="Jamulus Development Team" DEBEMAIL=team@jamulus.io

# Generate Changelog
echo -n generating changelog
rm -f debian/changelog
dch --create --package koord --empty --newversion "${VERSION}" ''
perl .github/actions_scripts/getChangelog.pl ChangeLog "${VERSION}" --line-per-entry | while read -r entry
do
    echo -n .
    dch "$entry"
done
echo

echo "${VERSION} building..."

CC=$(dpkg-architecture -A"${TARGET_ARCH}" -qDEB_TARGET_GNU_TYPE)-gcc
# Note: debuild only handles -a, not the long form --host-arch
# There must be no space after -a either, otherwise debuild cannot recognize it and fails during Changelog checks.

# export PATH=${QTADDPATH}
# echo "PATH = : ${PATH}"
# export PATH=/usr/lib/qt6/bin:${PATH}

echo "Executing debuild ....."
CC="${CC}" debuild --preserve-env -b -us -uc -j -a"${TARGET_ARCH}" --target-arch "${TARGET_ARCH}"
