#! /bin/bash

export LC_ALL=C.UTF-8
export LANG=C.UTF-8

polyswarmd_orig --log=INFO --host=127.0.0.1 --port=31338 &
nginx -c /usr/src/app/tls/nginx.conf
