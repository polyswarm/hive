#! /bin/bash

pushd terraform_e2e

if [ ! -d ".terraform/" ]; then
  terraform init -backend-config=.config
fi

terraform apply

popd
