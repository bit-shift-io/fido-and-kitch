#!/bin/sh
set -e

if [[ -z "${BUTLER_API_KEY}" ]]; then
  echo "Unable to deploy! No BUTLER_API_KEY environment variable specified!"
  exit 1
fi

prepare_butler() {
    echo "Preparing butler..."
    download_if_not_exist http://dl.itch.ovh/butler/linux-amd64/head/butler butler
    sudo chmod +x butler
}

prepare_and_push() {
    echo "Push $3 build to itch.io..."
    ./butler push $2 $1:$3
}

download_if_not_exist() {
    if [ ! -f $2 ]; then
        curl -L -O $1 > $2
    fi
}

project="bitshift/fido-and-kitch"
artifact="qwe"
platform="windows"

prepare_butler

prepare_and_push $project $artifact $platform

echo "Done."
exit 0


versionArgument=""

if [ "$VERSION" != "" ]
then
    versionArgument="--userversion ${VERSION}"
elif [ "$VERSION_FILE" != "" ]
then
    versionArgument="--userversion-file ${VERSION_FILE}"
fi

echo "butler push \"$1\" $ITCH_USER/$ITCH_GAME:$CHANNEL ${versionArgument}"
butler push "$1" $ITCH_USER/$ITCH_GAME:$CHANNEL ${versionArgument}