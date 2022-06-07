#!/bin/bash

export TZ='Asia/Shanghai'

hexo clean

git config submodule.themes/butterfly.url https://github.com/jerryc127/hexo-theme-butterfly.git 

git submodule update --init --recursive
git submodule update --recursive --remote

npm install

hexo generate
