#!/bin/bash

OS="$(uname -s)"
if [ ${OS} = "Linux" ]
then
    love $PWD
else
    /Applications/love.app/Contents/MacOS/love $PWD
fi
