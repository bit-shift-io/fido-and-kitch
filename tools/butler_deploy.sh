#!/bin/sh
set -e

export BUTLER_API_KEY=$BUTLER_CREDENTIALS

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