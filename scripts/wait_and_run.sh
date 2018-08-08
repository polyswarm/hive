#! /bin/bash

./scripts/wait_for_it.sh $POLYSWARMD_HOST:$POLYSWARMD_PORT -t 0

python ./scripts/listen_to_arbiter_events.py
