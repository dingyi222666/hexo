#!/bin/bash
set -e

export TZ='Asia/Shanghai'

npm install

# Call the locally installed CLI by path instead of relying on node_modules/.bin
# being on PATH — `bash vercel.sh` on its own does not have it.
HEXO=./node_modules/.bin/hexo

"$HEXO" clean
"$HEXO" generate
