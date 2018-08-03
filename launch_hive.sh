#! /bin/bash

pushd terraform

if [ ! -d ".terraform/" ]; then
  terraform init -backend-config=.config
fi

terraform apply

popd
