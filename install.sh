#!/bin/bash

mkdir thirdparty
cd thirdparty

git clone -b v2.3.1 --depth 1 git@github.com:kikito/anim8.git
git clone --depth 1 https://github.com/sbseltzer/love-bone