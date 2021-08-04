#!/bin/bash

rm -rf thirdparty
rm -rf sti

mkdir thirdparty
cd thirdparty

# unsed libs
#git clone -b v2.3.1 --depth 1 git@github.com:kikito/anim8.git
#git clone --depth 1 https://github.com/sbseltzer/love-bone

# build using v1.2.3.0
git clone --depth 1 https://github.com/karai17/Simple-Tiled-Implementation
mv Simple-Tiled-Implementation/sti ../

cd ..
rm -rf thirdparty