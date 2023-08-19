#!/bin/bash

export TZ='Asia/Shanghai'

hexo clean

git config submodule.themes/volantis.url https://github.com/volantis-x/hexo-theme-volantis.git

git submodule update --init --recursive
git submodule update --recursive --remote

cd themes/volantis
git checkout 6.0

cd ../..

npm install

hexo generate
