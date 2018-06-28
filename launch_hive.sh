#! /bin/bash

if [ ! -d ".terraform/" ]; then
  terraform init
fi

terraform apply 