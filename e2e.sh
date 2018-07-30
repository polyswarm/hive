#! /bin/bash

pushd terraform_e2e

if [ ! -d ".terraform/" ]; then
  terraform init
fi

terraform apply

popd
