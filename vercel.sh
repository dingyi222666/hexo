#!/bin/bash

export TZ='Asia/Shanghai'

hexo clean

git submodule update --init --recursive
git submodule update --recursive --remote

npm install

hexo generate
