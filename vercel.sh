#!/bin/bash
set -e

export TZ='Asia/Shanghai'

hexo clean

git submodule sync -- themes/volantis
git submodule update --init --recursive --remote -- themes/volantis

npm install

hexo generate
