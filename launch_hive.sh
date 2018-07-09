#! /bin/bash

pushd terraform

if [ ! -d ".terraform/" ]; then
  terraform init
fi

terraform apply

popd
