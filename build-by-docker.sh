#!/usr/bin/env bash

set -e

docker build -t builder .
docker run -v $(pwd):/workspace --network none builder build-in-docker.sh