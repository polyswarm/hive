#! /bin/bash

git clone https://github.com/polyswarm/polyswarmd.git
pushd polyswarmd
cp docker/Dockerfile ./
docker build -t local/polyswarmd .
popd

curl -L https://github.com/docker/compose/releases/download/1.18.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

docker-compose -f ./docker-compose-priv-testnet up
