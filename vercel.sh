#!/bin/bash

export TZ='Asia/Shanghai'

git submodule update --init --recursive
git submodule update --recursive --remote

npm install

hexo generate
