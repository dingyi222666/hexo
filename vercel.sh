#!/bin/bash

export TZ='Asia/Shanghai'

hexo clean

git config submodule.themes/volantis.url https://github.com/volantis-x/hexo-theme-volantis.git

git submodule sync -- themes/volantis
git submodule update --init --recursive -- themes/volantis
git submodule update --remote --checkout --recursive -- themes/volantis

npm install

hexo generate
