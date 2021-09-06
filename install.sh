#!/bin/bash

rm -rf thirdparty
rm -rf sti
mkdir lib
cd lib

# unsed libs
#git clone -b v2.3.1 --depth 1 git@github.com:kikito/anim8.git
#git clone --depth 1 https://github.com/sbseltzer/love-bone

# build using v1.2.3.0
git clone --depth 1 https://github.com/karai17/Simple-Tiled-Implementation
mv Simple-Tiled-Implementation/sti ../lib/
rm -rf Simple-Tiled-Implementation

git clone --depth 1 git@github.com:vrld/hump.git

git clone --depth 1 git@github.com:kikito/tween.lua.git tween

git clone --depth 1 git@github.com:flamendless/Slab.git

#git clone --depth 1 git@github.com:tavuntu/urutora.git urutora_temp
#mv urutora_temp/urutora urutora
#rm -rf urutora_temp

# git clone --depth 1 git@github.com:vrld/suit.git

# git clone --depth 1 git@github.com:kyleconroy/lua-state-machine.git

cd ..

# linux love engine
OS="$(uname -s)"
if [ ${OS} = "Linux" ]
then
    yay -S love --noconfirm --needed
fi

echo "Install complete"
