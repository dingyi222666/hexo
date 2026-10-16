#!/bin/bash
set -e

export TZ='Asia/Shanghai'

npm install

hexo clean
hexo generate
